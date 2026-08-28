[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$BackupFile,
  [switch]$ConfirmRestore
)

if (-not $ConfirmRestore) {
  throw 'Restore is destructive. Re-run with -ConfirmRestore after verifying the target database.'
}
if (-not (Test-Path -LiteralPath $BackupFile)) {
  throw "Backup not found: $BackupFile"
}

$required = 'DATABASE_HOST', 'DATABASE_PORT', 'DATABASE_NAME', 'DATABASE_USER', 'DATABASE_PASSWORD'
foreach ($name in $required) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    throw "Missing required environment variable: $name"
  }
}

$env:PGPASSWORD = $env:DATABASE_PASSWORD
try {
  & pg_restore --host $env:DATABASE_HOST --port $env:DATABASE_PORT --username $env:DATABASE_USER --dbname $env:DATABASE_NAME --clean --if-exists --no-owner $BackupFile
  if ($LASTEXITCODE -ne 0) { throw 'pg_restore failed.' }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
