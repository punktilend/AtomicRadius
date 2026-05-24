param(
  [string]$ScyllaStackName = "atomic-radius-scylla-ec2",
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
  --stack-name $ScyllaStackName `
  --query "Stacks[0].Outputs" `
  --output json | ConvertFrom-Json

function Get-Output {
  param([string]$Key)
  $match = $outputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if (-not $match) {
    throw "Missing Scylla stack output: $Key"
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

function Put-Parameter {
  param(
    [string]$Name,
    [string]$Type,
    [string]$Value,
    [string]$Description
  )

  $payload = @{
    Name = $Name
    Type = $Type
    Value = $Value
    Description = $Description
    Overwrite = $true
  }
  $jsonPath = Join-Path ([System.IO.Path]::GetTempPath()) ("atomic-radius-cassandra-ssm-{0}.json" -f ([System.Guid]::NewGuid()))
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

$configPrefix = "/$ProjectName/$EnvironmentName/config"
$secretPrefix = "/$ProjectName/$EnvironmentName/secrets"

Put-Parameter "$configPrefix/CASSANDRA_HOSTS" "String" (Get-Output "CassandraHosts") "Atomic Radius Cassandra hosts."
Put-Parameter "$configPrefix/CASSANDRA_KEYSPACE" "String" (Get-Output "CassandraKeyspace") "Atomic Radius Cassandra keyspace."
Put-Parameter "$configPrefix/CASSANDRA_LOCAL_DC" "String" (Get-Output "CassandraLocalDatacenter") "Atomic Radius Cassandra local datacenter."
Put-Parameter "$configPrefix/CASSANDRA_USERNAME" "String" (Get-Output "CassandraUsername") "Atomic Radius Cassandra username."
Put-Parameter "$secretPrefix/cassandra_password" "SecureString" (Get-SecretString (Get-Output "CassandraPasswordSecretArn")) "Atomic Radius Cassandra password."
