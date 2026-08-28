[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory
)

$required = 'DATABASE_HOST', 'DATABASE_PORT', 'DATABASE_NAME', 'DATABASE_USER', 'DATABASE_PASSWORD'
foreach ($name in $required) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    throw "Missing required environment variable: $name"
  }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$file = Join-Path $OutputDirectory ("fleet-control-$timestamp.dump")
$env:PGPASSWORD = $env:DATABASE_PASSWORD

try {
  & pg_dump --host $env:DATABASE_HOST --port $env:DATABASE_PORT --username $env:DATABASE_USER --format=custom --no-owner --file $file $env:DATABASE_NAME
  if ($LASTEXITCODE -ne 0) { throw 'pg_dump failed.' }
  Write-Output $file
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
