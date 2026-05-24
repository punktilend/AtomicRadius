param(
  [string]$MapPath = "",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$SourceEndpoint = $env:B2_ENDPOINT_URL,
  [string]$SourceRegion = $env:B2_REGION,
  [string]$SourceAccessKeyId = $env:B2_KEY_ID,
  [string]$SourceSecretAccessKey = $env:B2_APPLICATION_KEY,
  [string]$TargetRegion = "",
  [string]$TargetProfile = ""
)

$ErrorActionPreference = "Stop"

if (-not $MapPath) {
  $MapPath = Join-Path $PSScriptRoot "object-storage-map.json"
}

if (-not $SourceEndpoint -or -not $SourceRegion -or -not $SourceAccessKeyId -or -not $SourceSecretAccessKey) {
  throw "Set B2_ENDPOINT_URL, B2_REGION, B2_KEY_ID, and B2_APPLICATION_KEY in the environment before running."
}

$map = Get-Content -LiteralPath $MapPath -Raw | ConvertFrom-Json

$awsArgs = @()
if ($TargetProfile) {
  $awsArgs += @("--profile", $TargetProfile)
}
if ($TargetRegion) {
  $awsArgs += @("--region", $TargetRegion)
}

$foundationOutputs = & aws @awsArgs cloudformation describe-stacks `
  --stack-name $FoundationStackName `
  --query "Stacks[0].Outputs" `
  --output json | ConvertFrom-Json

function Get-FoundationOutput {
  param([string]$Key)
  $match = $foundationOutputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if (-not $match) {
    throw "Missing foundation output: $Key"
  }
  return $match.OutputValue
}

function Get-RequiredEnv {
  param([string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name)
  if (-not $value) {
    throw "Missing source bucket environment variable: $Name"
  }
  return $value
}

function Measure-S3Bucket {
  param(
    [string]$BucketName,
    [string[]]$ExtraArgs,
    [hashtable]$TemporaryEnvironment = @{}
  )

  $previousValues = @{}
  foreach ($key in $TemporaryEnvironment.Keys) {
    $previousValues[$key] = [Environment]::GetEnvironmentVariable($key)
    [Environment]::SetEnvironmentVariable($key, [string]$TemporaryEnvironment[$key], "Process")
  }

  try {
    $objects = & aws @ExtraArgs s3api list-objects-v2 `
      --bucket $BucketName `
      --query "Contents[].Size" `
      --output json | ConvertFrom-Json
  } finally {
    foreach ($key in $TemporaryEnvironment.Keys) {
      [Environment]::SetEnvironmentVariable($key, $previousValues[$key], "Process")
    }
  }

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to list bucket: $BucketName"
  }

  if (-not $objects) {
    return [pscustomobject]@{ Count = 0; Bytes = 0 }
  }

  $count = @($objects).Count
  $bytes = 0L
  foreach ($size in @($objects)) {
    $bytes += [int64]$size
  }

  return [pscustomobject]@{ Count = $count; Bytes = $bytes }
}

$sourceArgs = @(
  "--endpoint-url", $SourceEndpoint,
  "--region", $SourceRegion
)

$rows = @()
foreach ($bucket in $map.buckets) {
  $sourceBucket = Get-RequiredEnv $bucket.sourceBucketEnv
  $targetBucket = Get-FoundationOutput $bucket.targetFoundationOutput

  $source = Measure-S3Bucket `
    -BucketName $sourceBucket `
    -ExtraArgs $sourceArgs `
    -TemporaryEnvironment @{
      AWS_ACCESS_KEY_ID = $SourceAccessKeyId
      AWS_SECRET_ACCESS_KEY = $SourceSecretAccessKey
    }

  $target = Measure-S3Bucket -BucketName $targetBucket -ExtraArgs $awsArgs

  $rows += [pscustomobject]@{
    Name = $bucket.name
    SourceBucket = $sourceBucket
    SourceObjects = $source.Count
    SourceBytes = $source.Bytes
    TargetBucket = $targetBucket
    TargetObjects = $target.Count
    TargetBytes = $target.Bytes
    ObjectDelta = $source.Count - $target.Count
    ByteDelta = $source.Bytes - $target.Bytes
  }
}

$rows | Format-Table -AutoSize
