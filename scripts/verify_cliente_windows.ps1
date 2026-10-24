# Executa verificações locais sem provisionar serviços externos.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root 'apps/cliente')
try {
  foreach ($argsList in @(@('pub','get'), @('analyze'), @('test'))) {
    & flutter @argsList
    if ($LASTEXITCODE -ne 0) { throw "flutter $($argsList -join ' ') falhou ($LASTEXITCODE)" }
  }
  Write-Host 'Verificações locais concluídas.'
} finally { Pop-Location }
