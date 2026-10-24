# GOGDELY Cliente — inicialização local Windows (sem deploy)
# Execute da raiz do repositório: powershell -ExecutionPolicy Bypass -File scripts/setup_cliente_windows.ps1
[CmdletBinding()]
param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'apps/cliente'

function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
  Write-Host ('> ' + $Executable + ' ' + ($Arguments -join ' '))
  & $Executable @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Executable falhou com código $LASTEXITCODE" }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK não encontrado no PATH. Instale o Flutter e execute flutter doctor.'
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'Git não encontrado no PATH.'
}
Push-Location $root
try {
  $dirty = & git status --porcelain --untracked-files=normal
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar estado do Git.' }
  if ($dirty) { throw 'Há alterações locais não commitadas. Salve-as antes de gerar o scaffolding.' }
  Invoke-Checked 'flutter' @('--version')
  Invoke-Checked 'flutter' @('doctor')
  Push-Location $app
  try {
    # No Windows, gerar Android/Web. O scaffold iOS e a compilação iOS exigem macOS/Xcode.
    # flutter create preserva arquivos existentes por padrão (sem --overwrite).
    Invoke-Checked 'flutter' @('create', '--platforms=android,web', '--no-pub', '.')
    Invoke-Checked 'flutter' @('pub', 'get')
    if (-not $SkipTests) {
      Invoke-Checked 'flutter' @('analyze')
      Invoke-Checked 'flutter' @('test')
    }
  } finally { Pop-Location }
  Write-Host 'Preparação local concluída. Revise git status antes de qualquer commit.'
  Write-Host 'No VS Code: selecione GOGDELY Cliente • Laboratório (Chrome) e pressione F5.'
} finally { Pop-Location }
