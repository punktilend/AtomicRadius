param(
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

$configPrefix = "/$ProjectName/$EnvironmentName/config"
$secretPrefix = "/$ProjectName/$EnvironmentName/secrets"

$requiredParameters = @(
  "$secretPrefix/database_url",
  "$secretPrefix/redis_url",
  "$configPrefix/CASSANDRA_HOSTS",
  "$configPrefix/CASSANDRA_KEYSPACE",
  "$configPrefix/CASSANDRA_LOCAL_DC",
  "$configPrefix/CASSANDRA_USERNAME",
  "$secretPrefix/cassandra_password"
)

$invalid = & aws @awsArgs ssm get-parameters `
  --names $requiredParameters `
  --with-decryption `
  --query "InvalidParameters" `
  --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
  throw "Failed to check runtime SSM parameters."
}

if ($invalid -and $invalid.Count -gt 0) {
  Write-Host "Missing runtime parameters required before promoting API task definitions:"
  foreach ($name in $invalid) {
    Write-Host "  - $name"
  }
  throw "Runtime is not ready. Create the data and Scylla stacks, then run sync-data-runtime.ps1 and sync-scylla-runtime.ps1."
}

Write-Host "Runtime SSM parameters are present for $ProjectName/$EnvironmentName."
