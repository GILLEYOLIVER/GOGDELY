[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statePath = Join-Path $root '.local/pwa/state.json'
if (-not (Test-Path $statePath)) { Write-Host 'GOGDELY PWA já está parado.'; exit 0 }
$state = Get-Content $statePath -Raw | ConvertFrom-Json
foreach ($entry in @(
    @{pid=$state.apiPid;marker='gogdely_api.main:app'},
    @{pid=$state.certPid;marker='http.server'}
)) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($entry.pid)" -ErrorAction SilentlyContinue
    if ($proc -and $proc.CommandLine -like "*$($entry.marker)*") {
        Stop-Process -Id $proc.ProcessId
    }
}
Remove-Item -LiteralPath $statePath
Write-Host 'GOGDELY PWA local encerrado.'
