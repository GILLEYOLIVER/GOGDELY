$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$state = Join-Path $repo 'services\api\.local\f5-processes.json'
if (-not (Test-Path -LiteralPath $state)) { exit 0 }
try {
    $owned = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    foreach ($item in $owned) {
        $current = Get-CimInstance Win32_Process -Filter "ProcessId = $($item.pid)" -ErrorAction SilentlyContinue
        if ($current -and $current.ExecutablePath -ieq $item.path) {
            Stop-Process -Id $item.pid -ErrorAction SilentlyContinue
        }
    }
} finally {
    Remove-Item -LiteralPath $state -ErrorAction SilentlyContinue
}
