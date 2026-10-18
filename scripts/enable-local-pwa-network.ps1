[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statePath = Join-Path $root '.local/pwa/state.json'
if (-not (Test-Path $statePath)) { throw 'Inicie o PWA local primeiro.' }
$state = Get-Content $statePath -Raw | ConvertFrom-Json
$proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($state.apiPid)" -ErrorAction SilentlyContinue
if (-not $proc -or $proc.CommandLine -notlike '*gogdely_api.main:app*') { throw 'O servidor local não está ativo.' }
$ip = [string]$state.ip
if (-not (Get-NetIPAddress -AddressFamily IPv4 -IPAddress $ip -ErrorAction SilentlyContinue)) {
    throw 'O IP do PWA não pertence à rede ativa.'
}
$helper = Join-Path $PSScriptRoot 'local-pwa-firewall.ps1'
$ruleName = 'GOGDELY-Local-PWA-Temporary'
function Test-Rule {
    $rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
    if (-not $rule -or $rule.Enabled -ne 'True' -or $rule.Direction -ne 'Inbound' -or $rule.Action -ne 'Allow') { return $false }
    $addresses = $rule | Get-NetFirewallAddressFilter
    $ports = $rule | Get-NetFirewallPortFilter
    return $addresses.LocalAddress -eq $ip -and
        @($ports.LocalPort) -contains ([string]$state.port) -and
        @($ports.LocalPort) -contains ([string]$state.certificatePort)
}
if (Test-Rule) { Write-Host 'Rede local do GOGDELY já está liberada.'; exit 0 }
$args = '-NoProfile -ExecutionPolicy Bypass -File "' + $helper + '" -LanIp ' + $ip +
    ' -ApiPid ' + $state.apiPid + ' -Port ' + $state.port + ' -CertificatePort ' + $state.certificatePort
Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args -WindowStyle Hidden | Out-Null
for ($i = 0; $i -lt 120; $i++) {
    if (Test-Rule) { Write-Host 'Rede local do GOGDELY liberada.'; exit 0 }
    Start-Sleep -Milliseconds 500
}
throw 'O Windows não confirmou a liberação de rede. Confira a solicitação de administrador.'
