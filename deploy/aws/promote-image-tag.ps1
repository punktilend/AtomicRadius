param(
  [string]$ImageTag = "main",
  [string]$StackName = "atomic-radius-task-definitions",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ClusterName = "atomic-radius-prod",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "",
  [string]$Profile = "",
  [switch]$SkipRuntimeCheck
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$commonArgs = @(
  "-ProjectName", $ProjectName,
  "-EnvironmentName", $EnvironmentName
)
if ($Region) {
  $commonArgs += @("-Region", $Region)
}
if ($Profile) {
  $commonArgs += @("-Profile", $Profile)
}

if (-not $SkipRuntimeCheck) {
  & (Join-Path $scriptDir "check-runtime-ready.ps1") @commonArgs

  if ($LASTEXITCODE -ne 0) {
    throw "Runtime readiness check failed."
  }
}

& (Join-Path $scriptDir "deploy-task-definitions.ps1") `
  -StackName $StackName `
  -FoundationStackName $FoundationStackName `
  -ImageTag $ImageTag `
  @commonArgs

if ($LASTEXITCODE -ne 0) {
  throw "Failed to deploy task definitions for image tag $ImageTag."
}

& (Join-Path $scriptDir "update-services-to-latest-taskdefs.ps1") `
  -ClusterName $ClusterName `
  @commonArgs

if ($LASTEXITCODE -ne 0) {
  throw "Failed to update ECS services to latest task definitions."
}
