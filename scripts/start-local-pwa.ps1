[CmdletBinding()]
param(
    [switch]$UseHotspot,
    [switch]$SkipBuild,
    [string]$LanIp = '',
    [int]$Port = 8767,
    [int]$CertificatePort = 8768
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$apiDir = Join-Path $root 'services/api'
$python = Join-Path $apiDir '.venv/Scripts/python.exe'
$flutter = Join-Path $env:USERPROFILE 'develop/flutter/bin/flutter.bat'
$openssl = 'C:\Program Files\Git\usr\bin\openssl.exe'
$private = Join-Path $root '.local/pwa'
$certPublic = Join-Path $private 'public'
$statePath = Join-Path $private 'state.json'
$build = Join-Path $root 'apps/cliente/build/web'
$courierBuild = Join-Path $root 'apps/entregador/build/web'

function Get-Owner([string]$Address, [int]$ListenPort) {
    $listener = Get-NetTCPConnection -LocalPort $ListenPort -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalAddress -in @($Address, '0.0.0.0', '::') } |
        Select-Object -First 1
    if ($listener) { return [int]$listener.OwningProcess }
    return $null
}

function Assert-PrivateIp([string]$Address) {
    if ($Address -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -or
        -not (Get-NetIPAddress -AddressFamily IPv4 -IPAddress $Address -ErrorAction SilentlyContinue)) {
        throw 'Informe um IPv4 privado ativo neste computador.'
    }
}

if (-not (Test-Path $python) -or -not (Test-Path $flutter) -or -not (Test-Path $openssl)) {
    throw 'Python da API, Flutter ou OpenSSL do Git ausente. Prepare o ambiente local primeiro.'
}

if ($UseHotspot) {
    $network = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]
    $tetherType = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]
    $profile = $network::GetInternetConnectionProfile()
    if (-not $profile) { throw 'O computador precisa de uma conexão ativa para iniciar o hotspot.' }
    $tether = $tetherType::CreateFromConnectionProfile($profile)
    if ($tether.TetheringOperationalState -ne 'On') {
        $null = $tether.StartTetheringAsync()
        for ($i = 0; $i -lt 30 -and $tether.TetheringOperationalState -ne 'On'; $i++) {
            Start-Sleep -Seconds 1
        }
        if ($tether.TetheringOperationalState -ne 'On') {
            throw 'Não foi possível ligar o hotspot. Confira Configurações > Rede e Internet > Hotspot móvel.'
        }
    }
    # Read the Wi-Fi Direct adapter itself. Another adapter can already own
    # 192.168.137.1, in which case Windows assigns a different hotspot IP.
    $LanIp = ''
    for ($i = 0; $i -lt 20 -and -not $LanIp; $i++) {
        $hotspotAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -like '*Wi-Fi Direct Virtual Adapter*' })
        foreach ($adapter in $hotspotAdapters) {
            $LanIp = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } |
                Select-Object -ExpandProperty IPAddress -First 1
            if ($LanIp) { break }
        }
        if ($LanIp) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $LanIp) { throw 'Hotspot ligado, mas sem IPv4 privado no adaptador Wi-Fi Direct.' }
} elseif (-not $LanIp) {
    $route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
        Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1
    $LanIp = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex |
        Where-Object { $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } |
        Select-Object -ExpandProperty IPAddress -First 1
}
Assert-PrivateIp $LanIp

if (Test-Path $statePath) {
    $previous = Get-Content $statePath -Raw | ConvertFrom-Json
    $server = Get-CimInstance Win32_Process -Filter "ProcessId=$($previous.apiPid)" -ErrorAction SilentlyContinue
    if ($server -and $server.CommandLine -like '*gogdely_api.main:app*') {
        if ($SkipBuild -and $previous.ip -eq $LanIp -and $previous.port -eq $Port -and
            (Get-Owner $LanIp $Port) -eq [int]$previous.apiPid) {
            Write-Host "GOGDELY já está ativo: https://${LanIp}:$Port"
            exit 0
        }
        & (Join-Path $PSScriptRoot 'stop-local-pwa.ps1')
        Start-Sleep -Milliseconds 500
        $server = $null
    }
    if ($server) { throw 'Há outro servidor GOGDELY ativo. Encerre-o pelo atalho antes de reiniciar em outra rede.' }
    if (Test-Path $statePath) { Remove-Item -LiteralPath $statePath }
}
foreach ($checkPort in @($Port, $CertificatePort)) {
    $owner = Get-Owner $LanIp $checkPort
    if ($null -ne $owner) { throw "A porta $checkPort já pertence ao processo $owner." }
}

New-Item -ItemType Directory -Force -Path $private, $certPublic | Out-Null
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$directGrant = "*$($sid):F"
$inheritedGrant = "*$($sid):(OI)(CI)F"
& icacls.exe $private /inheritance:r /grant:r $directGrant /T | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível restringir o acesso aos certificados locais.' }
& icacls.exe $private /grant $inheritedGrant /T | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível restringir o acesso aos certificados locais.' }
$caKey = Join-Path $private 'GOGDELY-Local-CA.key'
$caPem = Join-Path $private 'GOGDELY-Local-CA.pem'
$serverKey = Join-Path $private 'server.key'
$serverPem = Join-Path $private 'server.pem'
if ((Test-Path $caKey) -xor (Test-Path $caPem)) { throw 'Certificado local incompleto; preserve os arquivos e repare antes de continuar.' }
if (-not (Test-Path $caKey)) {
    $ErrorActionPreference = 'Continue' # OpenSSL writes key-generation progress to stderr.
    & $openssl req -x509 -newkey rsa:3072 -nodes -days 365 -sha256 -subj '/CN=GOGDELY Local Test CA' `
        -addext 'basicConstraints=critical,CA:TRUE' -keyout $caKey -out $caPem 2>$null
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível criar a autoridade local de teste.' }
}
$csr = Join-Path $private 'server.csr'
$ext = Join-Path $private 'server.ext'
@("subjectAltName=IP:$LanIp", 'basicConstraints=CA:FALSE', 'extendedKeyUsage=serverAuth', 'keyUsage=digitalSignature,keyEncipherment') |
    Set-Content -LiteralPath $ext -Encoding ascii
$ErrorActionPreference = 'Continue'
& $openssl req -new -newkey rsa:2048 -nodes -subj '/CN=GOGDELY Local PWA' -keyout $serverKey -out $csr 2>$null
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível criar o certificado HTTPS.' }
$ErrorActionPreference = 'Continue'
& $openssl x509 -req -in $csr -CA $caPem -CAkey $caKey -CAcreateserial -days 30 -sha256 -extfile $ext -out $serverPem 2>$null
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível assinar o certificado HTTPS.' }
& $openssl x509 -in $caPem -outform DER -out (Join-Path $certPublic 'GOGDELY-Local-CA.cer')
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível preparar o certificado para o celular.' }
@"
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GOGDELY - teste de rede</title></head>
<body style="font:18px system-ui;padding:28px;line-height:1.5"><h1>Rede GOGDELY conectada</h1><p>O celular conseguiu alcançar o computador pela rede local.</p><p><a href="https://${LanIp}:$Port/">Abrir PWA GOGDELY</a></p><p>Se o HTTPS reclamar do certificado, <a href="/GOGDELY-Local-CA.cer">baixe o certificado de teste</a>.</p></body></html>
"@ | Set-Content -LiteralPath (Join-Path $certPublic 'index.html') -Encoding utf8

if ($SkipBuild) {
    if (-not (Test-Path (Join-Path $build 'index.html')) -or
        -not (Test-Path (Join-Path $build 'flutter_service_worker.js')) -or
        -not (Test-Path (Join-Path $courierBuild 'index.html'))) {
        throw 'Build PWA ausente. Inicie sem -SkipBuild.'
    }
} else {
    Push-Location (Join-Path $root 'apps/cliente')
    try {
        & $flutter build web --release --dart-define=GOGDELY_LOCAL_API=true --dart-define=GOGDELY_LOCAL_PWA=true
        if ($LASTEXITCODE -ne 0) { throw 'A compilação do Cliente web falhou.' }
    } finally { Pop-Location }
    Push-Location (Join-Path $root 'apps/entregador')
    try {
        & $flutter build web --release --base-href /entregador/ --dart-define=GOGDELY_LOCAL_API=true --dart-define=GOGDELY_LOCAL_PWA=true
        if ($LASTEXITCODE -ne 0) { throw 'A compilação do Entregador web falhou.' }
    } finally { Pop-Location }
}

$oldEnv = @{}
foreach ($name in @('GOGDELY_ENV','GOGDELY_LOCAL_DEMO','GOGDELY_LOCAL_PWA_DIR','GOGDELY_LOCAL_COURIER_DIR')) {
    $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$apiProcess = $null
$certProcess = $null
try {
    $env:GOGDELY_ENV = 'local'
    $env:GOGDELY_LOCAL_DEMO = '1'
    $env:GOGDELY_LOCAL_PWA_DIR = $build
    $env:GOGDELY_LOCAL_COURIER_DIR = $courierBuild
    $apiProcess = Start-Process -FilePath $python -ArgumentList @('-m','uvicorn','gogdely_api.main:app','--host',$LanIp,'--port',"$Port",'--ssl-keyfile',$serverKey,'--ssl-certfile',$serverPem) `
        -WorkingDirectory $apiDir -WindowStyle Hidden -RedirectStandardOutput (Join-Path $private 'api.out.log') `
        -RedirectStandardError (Join-Path $private 'api.err.log') -PassThru
    $certProcess = Start-Process -FilePath $python -ArgumentList @('-m','http.server',"$CertificatePort",'--bind',$LanIp,'--directory',$certPublic) `
        -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $private 'cert.out.log') `
        -RedirectStandardError (Join-Path $private 'cert.err.log') -PassThru
} finally {
    foreach ($name in $oldEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $oldEnv[$name], 'Process') }
}

$ready = $false
$apiOwner = $null
$certOwner = $null
for ($i = 0; $i -lt 45; $i++) {
    $apiOwner = Get-Owner $LanIp $Port
    $certOwner = Get-Owner $LanIp $CertificatePort
    $apiListener = if ($apiOwner) { Get-CimInstance Win32_Process -Filter "ProcessId=$apiOwner" -ErrorAction SilentlyContinue }
    $certListener = if ($certOwner) { Get-CimInstance Win32_Process -Filter "ProcessId=$certOwner" -ErrorAction SilentlyContinue }
    if ($apiListener -and $certListener -and
        $apiListener.ParentProcessId -eq $apiProcess.Id -and
        $certListener.ParentProcessId -eq $certProcess.Id -and
        $apiListener.CommandLine -like '*gogdely_api.main:app*' -and
        $certListener.CommandLine -like '*http.server*') {
        & curl.exe --silent --fail --ssl-no-revoke --max-time 3 --cacert $caPem "https://${LanIp}:$Port/api/v1/local/health" > $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    foreach ($pidToStop in @($apiOwner,$certOwner,$apiProcess.Id,$certProcess.Id)) {
        if ($pidToStop -and (Get-Process -Id $pidToStop -ErrorAction SilentlyContinue)) { Stop-Process -Id $pidToStop }
    }
    throw 'O servidor não ficou pronto. Consulte .local/pwa/api.err.log.'
}
@{apiPid=$apiOwner;certPid=$certOwner;ip=$LanIp;port=$Port;certificatePort=$CertificatePort} |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $statePath -Encoding utf8
$desktop = [Environment]::GetFolderPath('Desktop')
if ($desktop -and (Test-Path $desktop)) {
    $qrPath = Join-Path $desktop 'GOGDELY-PWA-QR.svg'
    & $python -c "import qrcode; from qrcode.image.svg import SvgPathImage; qrcode.make('https://${LanIp}:$Port', image_factory=SvgPathImage).save(r'$qrPath')"
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Não foi possível atualizar o QR na área de trabalho.' }
}
Write-Host "PWA local pronto: https://${LanIp}:$Port"
Write-Host "Prévia do Entregador: https://${LanIp}:$Port/entregador/"
Write-Host "Certificado para o celular: http://${LanIp}:$CertificatePort/GOGDELY-Local-CA.cer"
Write-Host 'Mantenha o computador ligado. Use scripts/stop-local-pwa.ps1 para encerrar.'
Write-Host 'Se o celular não abrir, libere as portas locais pelo auxiliar scripts/enable-local-pwa-network.ps1.'
