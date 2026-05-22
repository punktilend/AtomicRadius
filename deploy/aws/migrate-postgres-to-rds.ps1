param(
  [string]$SourceDatabaseUrl = $env:SOURCE_DATABASE_URL,
  [string]$TargetDatabaseUrl = "",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$DumpPath = "",
  [string]$Region = "",
  [string]$Profile = "",
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

if (-not $SourceDatabaseUrl) {
  throw "Set SOURCE_DATABASE_URL for the current RackNerd/Postgres source database."
}

if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
  throw "pg_dump is required. Install PostgreSQL client tools and ensure pg_dump is on PATH."
}

if (-not (Get-Command pg_restore -ErrorAction SilentlyContinue)) {
  throw "pg_restore is required. Install PostgreSQL client tools and ensure pg_restore is on PATH."
}

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

if (-not $TargetDatabaseUrl) {
  $TargetDatabaseUrl = & aws @awsArgs ssm get-parameter `
    --name "/$ProjectName/$EnvironmentName/secrets/database_url" `
    --with-decryption `
    --query "Parameter.Value" `
    --output text

  if ($LASTEXITCODE -ne 0 -or -not $TargetDatabaseUrl -or $TargetDatabaseUrl -eq "None") {
    throw "Could not read target database_url from SSM."
  }
}

if (-not $DumpPath) {
  $DumpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("atomic-radius-postgres-{0}.dump" -f (Get-Date -Format "yyyyMMddHHmmss"))
}

Write-Host "Dump path: $DumpPath"
Write-Host "Mode: $(if ($Apply) { 'apply' } else { 'dry-run' })"

if (-not $Apply) {
  Write-Host "Dry run only. Add -Apply to run pg_dump and pg_restore."
  return
}

& pg_dump `
  --dbname $SourceDatabaseUrl `
  --format custom `
  --no-owner `
  --no-acl `
  --file $DumpPath

if ($LASTEXITCODE -ne 0) {
  throw "pg_dump failed."
}

& pg_restore `
  --dbname $TargetDatabaseUrl `
  --clean `
  --if-exists `
  --no-owner `
  --no-acl `
  --jobs 4 `
  $DumpPath

if ($LASTEXITCODE -ne 0) {
  throw "pg_restore failed."
}

Write-Host "Postgres migration completed."
