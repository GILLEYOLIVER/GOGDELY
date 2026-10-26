[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [Parameter(Mandatory = $true)]
    [string]$CaCertificate,
    [string]$PgDumpPath = 'pg_dump',
    [string]$PgRestorePath = 'pg_restore'
)

$ErrorActionPreference = 'Stop'
$projectRef = 'vlcssgerbhbvekukpzki'
$poolerHost = 'aws-1-sa-east-1.pooler.supabase.com'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\', '/')
$repoPrefix = $repoRoot + [IO.Path]::DirectorySeparatorChar

if ($outputRoot.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputRoot.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Escolha uma pasta de backup fora do repositorio Git.'
}
if (-not (Test-Path -LiteralPath $CaCertificate -PathType Leaf)) {
    throw 'Baixe o certificado CA oficial em Supabase > Database > Settings > SSL configuration.'
}
$caPath = (Resolve-Path -LiteralPath $CaCertificate).Path

$pgDump = (Get-Command $PgDumpPath -ErrorAction Stop).Source
$pgRestore = (Get-Command $PgRestorePath -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputRoot = (Resolve-Path -LiteralPath $outputRoot).Path.TrimEnd('\', '/')
if ($outputRoot.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputRoot.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'A pasta de backup resolve para dentro do repositorio Git.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$archive = Join-Path $outputRoot "gogdely-homologacao-$stamp.dump"
$temporary = "$archive.partial"
$oldEnv = @{}
if ((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $temporary)) {
    throw 'Ja existe um arquivo de backup com esse nome.'
}
$settings = @{
    PGHOST = $poolerHost
    PGPORT = '5432'
    PGDATABASE = 'postgres'
    PGUSER = "postgres.$projectRef"
    PGSSLMODE = 'verify-full'
    PGSSLROOTCERT = $caPath
    PGPASSWORD = $null
    PGPASSFILE = $null
    PGSERVICE = $null
}

try {
    foreach ($key in $settings.Keys) {
        $oldEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        if ($null -eq $settings[$key]) {
            Remove-Item -LiteralPath ('Env:' + $key) -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($key, $settings[$key], 'Process')
        }
    }

    Write-Host "Projeto: GOGDELY Homologacao ($projectRef); esquema: gogdely."
    Write-Host 'O pg_dump pedira a senha do banco no terminal. Ela nao sera gravada pelo script.'
    & $pgDump --format=custom --schema=gogdely --file=$temporary --password
    if ($LASTEXITCODE -ne 0) { throw "pg_dump falhou (codigo $LASTEXITCODE)." }

    $listing = @(& $pgRestore --list $temporary)
    if ($LASTEXITCODE -ne 0) { throw "pg_restore nao conseguiu ler o arquivo (codigo $LASTEXITCODE)." }
    $tableNames = @('tenants', 'branches', 'memberships', 'membership_branches',
        'menu_items', 'orders', 'order_items', 'order_events')
    foreach ($tableName in $tableNames) {
        $pattern = '^\d+;.* TABLE gogdely ' + [regex]::Escape($tableName) + '\s'
        if (-not @($listing | Where-Object { $_ -match $pattern }).Count) {
            throw "O arquivo nao contem a tabela de base esperada: $tableName."
        }
    }
    if ((Get-Item -LiteralPath $temporary).Length -eq 0) { throw 'O arquivo de backup esta vazio.' }

    Move-Item -LiteralPath $temporary -Destination $archive
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $size = (Get-Item -LiteralPath $archive).Length
    Write-Host "Backup: $archive"
    Write-Host "Tamanho: $size bytes; SHA-256: $hash"
    Write-Host 'Verificacao do formato: pg_restore --list passou. Restauracao real ainda nao foi testada.'
}
finally {
    foreach ($key in $settings.Keys) {
        if ($null -eq $oldEnv[$key]) {
            Remove-Item -LiteralPath ('Env:' + $key) -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($key, $oldEnv[$key], 'Process')
        }
    }
    if (Test-Path -LiteralPath $temporary -PathType Leaf) {
        Remove-Item -LiteralPath $temporary -Force
    }
}
