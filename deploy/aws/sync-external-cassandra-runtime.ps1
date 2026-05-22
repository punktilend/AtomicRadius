param(
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$CassandraHosts = $env:CASSANDRA_HOSTS,
  [string]$CassandraKeyspace = $env:CASSANDRA_KEYSPACE,
  [string]$CassandraLocalDc = $env:CASSANDRA_LOCAL_DC,
  [string]$CassandraUsername = $env:CASSANDRA_USERNAME,
  [string]$CassandraPassword = $env:CASSANDRA_PASSWORD,
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

if (-not $CassandraHosts -or -not $CassandraKeyspace -or -not $CassandraLocalDc -or -not $CassandraUsername -or -not $CassandraPassword) {
  throw "Set CASSANDRA_HOSTS, CASSANDRA_KEYSPACE, CASSANDRA_LOCAL_DC, CASSANDRA_USERNAME, and CASSANDRA_PASSWORD before running."
}

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
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

Put-Parameter "$configPrefix/CASSANDRA_HOSTS" "String" $CassandraHosts "External Cassandra hosts for Atomic Radius $EnvironmentName."
Put-Parameter "$configPrefix/CASSANDRA_KEYSPACE" "String" $CassandraKeyspace "External Cassandra keyspace for Atomic Radius $EnvironmentName."
Put-Parameter "$configPrefix/CASSANDRA_LOCAL_DC" "String" $CassandraLocalDc "External Cassandra local datacenter for Atomic Radius $EnvironmentName."
Put-Parameter "$configPrefix/CASSANDRA_USERNAME" "String" $CassandraUsername "External Cassandra username for Atomic Radius $EnvironmentName."
Put-Parameter "$secretPrefix/cassandra_password" "SecureString" $CassandraPassword "External Cassandra password for Atomic Radius $EnvironmentName."
