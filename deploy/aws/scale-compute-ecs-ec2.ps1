param(
  [string]$AutoScalingGroupName = "atomic-radius-prod-ecs",
  [int]$MinSize = 1,
  [int]$DesiredCapacity = 1,
  [int]$MaxSize = 3,
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

& aws @awsArgs autoscaling update-auto-scaling-group `
  --auto-scaling-group-name $AutoScalingGroupName `
  --min-size $MinSize `
  --desired-capacity $DesiredCapacity `
  --max-size $MaxSize

if ($LASTEXITCODE -ne 0) {
  throw "Failed to update Auto Scaling Group capacity."
}

& aws @awsArgs autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names $AutoScalingGroupName `
  --query "AutoScalingGroups[0].{Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,Instances:Instances[].{InstanceId:InstanceId,LifecycleState:LifecycleState,HealthStatus:HealthStatus}}" `
  --output table
