param(
  [string]$ClusterName = "atomic-radius-prod",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [int]$Api = 0,
  [int]$ApiWorker = 0,
  [int]$Gateway = 0,
  [int]$MediaProxy = 0,
  [int]$Admin = 0,
  [int]$Marketing = 0,
  [int]$Docs = 0,
  [int]$Metrics = 0,
  [string]$Region = "",
  [string]$Profile = "",
  [switch]$Apply,
  [switch]$SkipRuntimeCheck,
  [switch]$Wait
)

$ErrorActionPreference = "Stop"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

$counts = [ordered]@{
  "api" = $Api
  "api-worker" = $ApiWorker
  "gateway" = $Gateway
  "media-proxy" = $MediaProxy
  "admin" = $Admin
  "marketing" = $Marketing
  "docs" = $Docs
  "metrics" = $Metrics
}

foreach ($entry in $counts.GetEnumerator()) {
  if ($entry.Value -lt 0) {
    throw "Desired count for $($entry.Key) cannot be negative."
  }
}

$startingRuntimeServices = @("api", "api-worker", "gateway", "media-proxy") | Where-Object { $counts[$_] -gt 0 }
if ($startingRuntimeServices.Count -gt 0 -and -not $SkipRuntimeCheck) {
  & (Join-Path $PSScriptRoot "check-runtime-ready.ps1") `
    -ProjectName $ProjectName `
    -EnvironmentName $EnvironmentName `
    -Region $Region `
    -Profile $Profile

  if ($LASTEXITCODE -ne 0) {
    throw "Runtime readiness check failed."
  }
}

Write-Host "Requested Fargate ECS desired counts:"
foreach ($entry in $counts.GetEnumerator()) {
  Write-Host ("  {0,-12} {1}" -f $entry.Key, $entry.Value)
}

if (-not $Apply) {
  Write-Host "`nDry run only. Add -Apply to update Fargate ECS services."
  return
}

$updatedServices = @()
foreach ($entry in $counts.GetEnumerator()) {
  $serviceName = "$ProjectName-$EnvironmentName-fargate-$($entry.Key)"
  & aws @awsArgs ecs update-service `
    --cluster $ClusterName `
    --service $serviceName `
    --desired-count $entry.Value `
    --query "service.{serviceName:serviceName,desiredCount:desiredCount,runningCount:runningCount,pendingCount:pendingCount,launchType:launchType}" `
    --output table

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to scale $serviceName."
  }

  $updatedServices += $serviceName
}

if ($Wait) {
  Write-Host "`nWaiting for Fargate ECS services to stabilize..."
  & aws @awsArgs ecs wait services-stable `
    --cluster $ClusterName `
    --services $updatedServices

  if ($LASTEXITCODE -ne 0) {
    throw "Fargate ECS services did not stabilize."
  }
}
