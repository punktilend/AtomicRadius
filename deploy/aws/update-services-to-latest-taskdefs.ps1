param(
  [string]$ClusterName = "atomic-radius-prod",
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

$families = @(
  "api",
  "api-worker",
  "app",
  "gateway",
  "media-proxy",
  "admin",
  "marketing",
  "docs",
  "metrics"
)

foreach ($family in $families) {
  $taskFamily = "$ProjectName-$EnvironmentName-$family"
  $serviceName = "$ProjectName-$EnvironmentName-$family"
  $taskDefinitionArn = & aws @awsArgs ecs list-task-definitions `
    --family-prefix $taskFamily `
    --status ACTIVE `
    --sort DESC `
    --max-items 1 `
    --query "taskDefinitionArns[0]" `
    --output text

  if (-not $taskDefinitionArn -or $taskDefinitionArn -eq "None") {
    throw "No active task definition found for $taskFamily."
  }

  & aws @awsArgs ecs update-service `
    --cluster $ClusterName `
    --service $serviceName `
    --task-definition $taskDefinitionArn `
    --query "service.{serviceName:serviceName,taskDefinition:taskDefinition,desiredCount:desiredCount,runningCount:runningCount}" `
    --output table

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to update $serviceName."
  }
}
