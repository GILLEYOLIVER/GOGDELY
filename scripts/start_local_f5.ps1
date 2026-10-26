$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$api = Join-Path $repo 'services\api'
$python = Join-Path $api '.venv\Scripts\python.exe'
$state = Join-Path $api '.local\f5-processes.json'
$health = 'http://127.0.0.1:8765/api/v1/local/health'
$owned = @()
$startedNow = @()
if (Test-Path -LiteralPath $state) {
    $previous = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    foreach ($item in $previous) {
        $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($item.pid)" -ErrorAction SilentlyContinue
        if ($current -and $current.ExecutablePath -ieq $item.path) {
            $owned += @{ pid = [int]$item.pid; path = [string]$item.path }
        }
    }
}

function Test-LocalApi {
    try {
        $reply = Invoke-RestMethod -Uri $health -TimeoutSec 2
        return $reply.status -eq 'ok' -and $reply.storage -eq 'sqlite-local-demo'
    } catch {
        return $false
    }
}

function Get-AppProcess([string]$exe) {
    $name = Split-Path -Leaf $exe
    foreach ($candidate in @(Get-CimInstance Win32_Process -Filter "name = '$name'" -ErrorAction SilentlyContinue)) {
        if ($candidate.ExecutablePath -ieq $exe) {
            $process = Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue
            if ($process -and $process.MainWindowHandle -ne 0) { return $candidate }
        }
    }
    return $null
}

try {
    if (Test-LocalApi) {
        $listener = Get-NetTCPConnection -LocalAddress '127.0.0.1' -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        $apiProcess = if ($listener) { Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue } else { $null }
        $newestApiSource = Get-ChildItem -LiteralPath (Join-Path $api 'gogdely_api') -Recurse -File -Filter '*.py' |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($apiProcess -and $newestApiSource -and $newestApiSource.LastWriteTimeUtc -gt $apiProcess.StartTime.ToUniversalTime()) {
            $trackedApi = $owned | Where-Object { $_.pid -eq $apiProcess.Id -and $_.path -ieq $python } | Select-Object -First 1
            if (-not $trackedApi) {
                throw 'A API local aberta usa codigo antigo e nao foi iniciada por este F5. Encerre-a e pressione F5 novamente.'
            }
            Stop-Process -Id $apiProcess.Id
            Wait-Process -Id $apiProcess.Id -Timeout 5 -ErrorAction SilentlyContinue
            $owned = @($owned | Where-Object { $_.pid -ne $apiProcess.Id })
            Start-Sleep -Milliseconds 400
        }
    }
    if (-not (Test-LocalApi)) {
        if (Get-NetTCPConnection -LocalAddress '127.0.0.1' -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue) {
            throw 'A porta 8765 ja esta ocupada por outro programa. Feche-o antes de usar F5.'
        }
        if (-not (Test-Path -LiteralPath $python)) {
            throw 'Ambiente Python da API ausente. Crie services/api/.venv e instale as dependencias.'
        }
        $oldEnv = $env:GOGDELY_ENV
        $oldDemo = $env:GOGDELY_LOCAL_DEMO
        try {
            $env:GOGDELY_ENV = 'local'
            $env:GOGDELY_LOCAL_DEMO = '1'
            $proc = Start-Process -FilePath $python -ArgumentList @('-m', 'uvicorn', 'gogdely_api.main:app', '--host', '127.0.0.1', '--port', '8765') -WorkingDirectory $api -WindowStyle Hidden -PassThru
            $owned += @{ pid = $proc.Id; path = $python }
            $startedNow += @{ pid = $proc.Id; path = $python }
        } finally {
            $env:GOGDELY_ENV = $oldEnv
            $env:GOGDELY_LOCAL_DEMO = $oldDemo
        }
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            if (Test-LocalApi) { $ready = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) { throw 'A API local nao respondeu na porta 8765.' }
    }

    foreach ($app in @('gestao', 'entregador')) {
        $appDir = Join-Path $repo "apps\$app"
        $exe = Join-Path $repo "apps\$app\build\windows\x64\runner\Debug\gogdely_$app.exe"
        $stamp = Join-Path $appDir 'build\windows\x64\runner\Debug\.gogdely-f5-built'
        $sourcePaths = @(
            (Join-Path $appDir 'lib'),
            (Join-Path $appDir 'assets'),
            (Join-Path $appDir 'pubspec.yaml'),
            (Join-Path $appDir 'pubspec.lock'),
            (Join-Path $repo 'packages\design_system\lib'),
            (Join-Path $repo 'packages\local_demo_api\lib')
        )
        $newestSource = $sourcePaths | Where-Object { Test-Path -LiteralPath $_ } |
            ForEach-Object { Get-Item -LiteralPath $_; if ((Get-Item -LiteralPath $_).PSIsContainer) { Get-ChildItem -LiteralPath $_ -Recurse -File } } |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        $needsBuild = -not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath $stamp)
        if (-not $needsBuild) {
            $needsBuild = $newestSource.LastWriteTimeUtc -gt (Get-Item -LiteralPath $stamp).LastWriteTimeUtc
        }
        if ($needsBuild) {
            $running = Get-AppProcess $exe
            if ($running) {
                $tracked = $owned | Where-Object { $_.pid -eq $running.ProcessId -and $_.path -ieq $exe } | Select-Object -First 1
                if (-not $tracked) {
                    throw "Feche a janela $app e pressione F5 novamente para aplicar as atualizacoes."
                }
                Stop-Process -Id $running.ProcessId
                $owned = @($owned | Where-Object { $_.pid -ne $running.ProcessId })
                $running = $null
            }
            $flutter = Get-Command flutter.bat -ErrorAction SilentlyContinue
            if (-not $flutter) {
                $settings = Get-Content -LiteralPath (Join-Path $repo '.vscode\settings.json') -Raw | ConvertFrom-Json
                $flutterPath = Join-Path $settings.'dart.flutterSdkPath' 'bin\flutter.bat'
                if (Test-Path -LiteralPath $flutterPath) { $flutter = @{ Source = $flutterPath } }
            }
            if (-not $flutter) { throw 'Flutter SDK nao encontrado para compilar o aplicativo Windows.' }
            Write-Host "Atualizando $app para este F5..."
            Push-Location $appDir
            try {
                & $flutter.Source build windows --debug --dart-define=GOGDELY_LOCAL_API=true
                if ($LASTEXITCODE -ne 0) { throw "A compilacao de $app falhou." }
                Set-Content -LiteralPath $stamp -Value 'GOGDELY_LOCAL_API=true' -Encoding ASCII
            } finally {
                Pop-Location
            }
        }
        if (-not (Test-Path -LiteralPath $exe)) {
            throw "Executavel $app ausente apos a compilacao."
        }
        $alreadyOpen = Get-AppProcess $exe
        if (-not $alreadyOpen) {
            Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) | Out-Null
            for ($i = 0; $i -lt 30; $i++) {
                $opened = Get-AppProcess $exe
                if ($opened) { break }
                Start-Sleep -Milliseconds 500
            }
            if (-not $opened) { throw "A janela $app nao abriu. Verifique o executavel Windows." }
            $owned += @{ pid = $opened.ProcessId; path = $exe }
            $startedNow += @{ pid = $opened.ProcessId; path = $exe }
        }
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $state) -Force | Out-Null
    ConvertTo-Json -InputObject @($owned) -Depth 3 | Set-Content -LiteralPath $state -Encoding UTF8
    Write-Host 'API, Gestao e Entregador prontos. Abrindo Cliente...'
} catch {
    foreach ($item in $startedNow) {
        $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($item.pid)" -ErrorAction SilentlyContinue
        if ($current -and $current.ExecutablePath -ieq $item.path) { Stop-Process -Id $item.pid -ErrorAction SilentlyContinue }
    }
    Write-Error $_
    exit 1
}
