param(
  [switch]$Apply,
  [string]$ClusterName = "atomic-radius-prod",
  [string]$EdgeStackName = "atomic-radius-edge-alb",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [switch]$Fargate,
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

try {
  $outputs = & aws @awsArgs cloudformation describe-stacks `
    --stack-name $EdgeStackName `
    --query "Stacks[0].Outputs" `
    --output json 2>$null | ConvertFrom-Json
} catch {
  if (-not $Apply) {
    Write-Host "Edge stack $EdgeStackName does not exist yet. Create it with deploy-edge-alb.ps1 -Apply before attaching services."
    return
  }
  throw
}

if (-not $outputs) {
  if (-not $Apply) {
    Write-Host "Edge stack $EdgeStackName does not exist yet. Create it with deploy-edge-alb.ps1 -Apply before attaching services."
    return
  }
  throw "Edge stack $EdgeStackName has no outputs."
}

function Get-Output {
  param([string]$Key)
  $match = $outputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if (-not $match) {
    throw "Missing edge stack output: $Key"
  }
  return $match.OutputValue
}

$attachments = @(
  @{ Service = "api"; Container = "api"; Port = 8080; TargetGroup = Get-Output "ApiTargetGroupArn" },
  @{ Service = "app"; Container = "app"; Port = 8080; TargetGroup = Get-Output "AppTargetGroupArn" },
  @{ Service = "gateway"; Container = "gateway"; Port = 8080; TargetGroup = Get-Output "GatewayTargetGroupArn" },
  @{ Service = "media-proxy"; Container = "media-proxy"; Port = 8080; TargetGroup = Get-Output "MediaProxyTargetGroupArn" },
  @{ Service = "admin"; Container = "admin"; Port = 8080; TargetGroup = Get-Output "AdminTargetGroupArn" },
  @{ Service = "marketing"; Container = "marketing"; Port = 8080; TargetGroup = Get-Output "MarketingTargetGroupArn" },
  @{ Service = "docs"; Container = "docs"; Port = 3000; TargetGroup = Get-Output "DocsTargetGroupArn" },
  @{ Service = "metrics"; Container = "metrics"; Port = 8080; TargetGroup = Get-Output "MetricsTargetGroupArn" }
)

foreach ($attachment in $attachments) {
  $serviceName = if ($Fargate) {
    "$ProjectName-$EnvironmentName-fargate-$($attachment.Service)"
  } else {
    "$ProjectName-$EnvironmentName-$($attachment.Service)"
  }
  $loadBalancer = "targetGroupArn=$($attachment.TargetGroup),containerName=$($attachment.Container),containerPort=$($attachment.Port)"

  if (-not $Apply) {
    Write-Host "Would attach $serviceName to $($attachment.TargetGroup)"
    continue
  }

  & aws @awsArgs ecs update-service `
    --cluster $ClusterName `
    --service $serviceName `
    --load-balancers $loadBalancer `
    --query "service.{serviceName:serviceName,desiredCount:desiredCount,runningCount:runningCount,loadBalancers:loadBalancers}" `
    --output table

  if ($LASTEXITCODE -ne 0) {
    throw "Failed to attach target group for $serviceName."
  }
}

if (-not $Apply) {
  Write-Host "Dry run only. Re-run with -Apply after the ALB stack exists to update ECS services."
}
