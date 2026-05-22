param(
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$ClusterName = "atomic-radius-prod",
  [string]$AutoScalingGroupName = "atomic-radius-prod-ecs",
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

$stackNames = @(
  "$ProjectName-foundation",
  "$ProjectName-compute-ecs-ec2",
  "$ProjectName-task-definitions",
  "$ProjectName-ecs-services-zero",
  "$ProjectName-ecs-services-fargate-zero",
  "$ProjectName-github-oidc",
  "$ProjectName-data-services",
  "$ProjectName-scylla-ec2",
  "$ProjectName-edge-alb",
  "$ProjectName-cloudfront-static",
  "$ProjectName-dns-zone",
  "$ProjectName-acm-certificates"
)

Write-Host "`nCloudFormation stacks"
foreach ($stackName in $stackNames) {
  $status = & aws @awsArgs cloudformation describe-stacks `
    --stack-name $stackName `
    --query "Stacks[0].StackStatus" `
    --output text 2>$null

  if ($LASTEXITCODE -eq 0 -and $status) {
    Write-Host ("  {0,-36} {1}" -f $stackName, $status)
  } else {
    Write-Host ("  {0,-36} NOT_CREATED" -f $stackName)
  }
}

Write-Host "`nECS cluster"
& aws @awsArgs ecs describe-clusters `
  --clusters $ClusterName `
  --query "clusters[0].{clusterName:clusterName,status:status,registeredContainerInstancesCount:registeredContainerInstancesCount,runningTasksCount:runningTasksCount,pendingTasksCount:pendingTasksCount,activeServicesCount:activeServicesCount}" `
  --output table

Write-Host "`nECS services"
$services = @(
  "api",
  "api-worker",
  "gateway",
  "media-proxy",
  "admin",
  "marketing",
  "docs",
  "metrics"
) | ForEach-Object { "$ProjectName-$EnvironmentName-$_" }

& aws @awsArgs ecs describe-services `
  --cluster $ClusterName `
  --services $services `
  --query "services[].{service:serviceName,status:status,desired:desiredCount,running:runningCount,pending:pendingCount,taskDefinition:taskDefinition}" `
  --output table

Write-Host "`nECS Fargate fallback services"
$fargateServices = @(
  "api",
  "api-worker",
  "gateway",
  "media-proxy",
  "admin",
  "marketing",
  "docs",
  "metrics"
) | ForEach-Object { "$ProjectName-$EnvironmentName-fargate-$_" }

& aws @awsArgs ecs describe-services `
  --cluster $ClusterName `
  --services $fargateServices `
  --query "services[].{service:serviceName,status:status,desired:desiredCount,running:runningCount,pending:pendingCount,taskDefinition:taskDefinition,launchType:launchType}" `
  --output table

Write-Host "`nAuto Scaling"
& aws @awsArgs autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names $AutoScalingGroupName `
  --query "AutoScalingGroups[0].{name:AutoScalingGroupName,min:MinSize,desired:DesiredCapacity,max:MaxSize,instances:Instances[].{id:InstanceId,state:LifecycleState,health:HealthStatus}}" `
  --output table

Write-Host "`nRuntime readiness"
try {
  & (Join-Path $PSScriptRoot "check-runtime-ready.ps1") `
    -ProjectName $ProjectName `
    -EnvironmentName $EnvironmentName `
    -Region $Region `
    -Profile $Profile
} catch {
  Write-Host $_.Exception.Message
}
