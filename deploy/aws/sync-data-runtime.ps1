param(
  [string]$DataStackName = "atomic-radius-data-services",
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

$outputs = & aws @awsArgs cloudformation describe-stacks `
  --stack-name $DataStackName `
  --query "Stacks[0].Outputs" `
  --output json | ConvertFrom-Json

function Get-Output {
  param([string]$Key)
  $match = $outputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if (-not $match) {
    throw "Missing data stack output: $Key"
  }
  return $match.OutputValue
}

function Get-SecretString {
  param([string]$SecretId)
  return & aws @awsArgs secretsmanager get-secret-value `
    --secret-id $SecretId `
    --query SecretString `
    --output text
}

function Put-SecureStringParameter {
  param(
    [string]$Name,
    [string]$Value,
    [string]$Description
  )

  $payload = @{
    Name = $Name
    Type = "SecureString"
    Value = $Value
    Description = $Description
    Overwrite = $true
  }
  $jsonPath = Join-Path ([System.IO.Path]::GetTempPath()) ("atomic-radius-secure-ssm-{0}.json" -f ([System.Guid]::NewGuid()))
  try {
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -NoNewline
    & aws @awsArgs ssm put-parameter --cli-input-json "file://$jsonPath" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to put SSM parameter $Name."
    }
  } finally {
    Remove-Item -LiteralPath $jsonPath -Force -ErrorAction SilentlyContinue
  }

  Write-Host $Name
}

$postgresSecretArn = Get-Output "PostgresMasterUserSecretArn"
$postgresSecret = Get-SecretString $postgresSecretArn | ConvertFrom-Json
$postgresHost = Get-Output "PostgresEndpointAddress"
$postgresPort = Get-Output "PostgresEndpointPort"
$postgresDb = Get-Output "PostgresDatabaseName"
$postgresUser = [uri]::EscapeDataString([string]$postgresSecret.username)
$postgresPass = [uri]::EscapeDataString([string]$postgresSecret.password)
$databaseUrl = "postgresql://${postgresUser}:${postgresPass}@${postgresHost}:${postgresPort}/${postgresDb}"

$valkeySecretArn = Get-Output "ValkeyAuthSecretArn"
$valkeyToken = [uri]::EscapeDataString((Get-SecretString $valkeySecretArn))
$valkeyHost = Get-Output "ValkeyPrimaryEndpointAddress"
$valkeyPort = Get-Output "ValkeyPrimaryEndpointPort"
$redisUrl = "rediss://default:${valkeyToken}@${valkeyHost}:${valkeyPort}"

$prefix = "/$ProjectName/$EnvironmentName/secrets"

Put-SecureStringParameter `
  -Name "$prefix/database_url" `
  -Value $databaseUrl `
  -Description "Atomic Radius $EnvironmentName DATABASE_URL."

Put-SecureStringParameter `
  -Name "$prefix/redis_url" `
  -Value $redisUrl `
  -Description "Atomic Radius $EnvironmentName REDIS_URL."
