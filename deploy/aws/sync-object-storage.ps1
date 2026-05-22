param(
  [string]$MapPath = "",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$SourceEndpoint = $env:B2_ENDPOINT_URL,
  [string]$SourceRegion = $env:B2_REGION,
  [string]$SourceAccessKeyId = $env:B2_KEY_ID,
  [string]$SourceSecretAccessKey = $env:B2_APPLICATION_KEY,
  [string]$TargetRegion = "",
  [string]$TargetProfile = "",
  [int]$Transfers = 8,
  [int]$Checkers = 16,
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

if (-not $MapPath) {
  $MapPath = Join-Path $PSScriptRoot "object-storage-map.json"
}

if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
  throw "rclone is required for direct S3-compatible to AWS S3 sync. Install rclone, then rerun this script."
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

if ($LASTEXITCODE -ne 0) {
  throw "Failed to read foundation stack outputs."
}

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

$targetRegionValue = $TargetRegion
if (-not $targetRegionValue) {
  $targetRegionValue = (& aws @awsArgs configure get region)
}
if (-not $targetRegionValue) {
  $targetRegionValue = "us-east-1"
}

$configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("atomic-radius-rclone-{0}.conf" -f ([System.Guid]::NewGuid()))

try {
  $config = @"
[b2src]
type = s3
provider = Other
env_auth = false
access_key_id = $SourceAccessKeyId
secret_access_key = $SourceSecretAccessKey
endpoint = $SourceEndpoint
region = $SourceRegion
acl = private

"@

  $config += "`n[awsdst]`n"
  $config += "type = s3`n"
  $config += "provider = AWS`n"
  if ($TargetProfile) {
    $config += "env_auth = false`n"
    $config += "profile = $TargetProfile`n"
  } else {
    $config += "env_auth = true`n"
  }
  $config += "region = $targetRegionValue`n"
  $config += "acl = private`n"

  Set-Content -LiteralPath $configPath -Value $config -NoNewline

  foreach ($bucket in $map.buckets) {
    $sourceBucket = Get-RequiredEnv $bucket.sourceBucketEnv
    $targetBucket = Get-FoundationOutput $bucket.targetFoundationOutput
    $mode = if ($Apply) { "sync" } else { "dry-run" }

    Write-Host "`n[$($bucket.name)] $mode"
    Write-Host "  source: $sourceBucket"
    Write-Host "  target: $targetBucket"

    $rcloneArgs = @(
      "--config", $configPath,
      "sync",
      "b2src:$sourceBucket",
      "awsdst:$targetBucket",
      "--transfers", $Transfers,
      "--checkers", $Checkers,
      "--fast-list",
      "--stats", "30s",
      "--stats-one-line"
    )

    if (-not $Apply) {
      $rcloneArgs += "--dry-run"
    }

    & rclone @rcloneArgs
    if ($LASTEXITCODE -ne 0) {
      throw "rclone sync failed for $($bucket.name)."
    }
  }
} finally {
  Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
}
