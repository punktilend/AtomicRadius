param(
  [string]$StackName = "atomic-radius-ecs-services-zero",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ComputeStackName = "atomic-radius-compute-ecs-ec2",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [int]$DesiredCount = 0,
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "ecs-services-zero.yaml"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

function Get-StackOutputMap {
  param([string]$Name)
  return & aws @awsArgs cloudformation describe-stacks `
    --stack-name $Name `
    --query "Stacks[0].Outputs" `
    --output json | ConvertFrom-Json
}

function Get-Output {
  param(
    [object[]]$Outputs,
    [string]$Key
  )
  $match = $Outputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if (-not $match) {
    throw "Missing stack output: $Key"
  }
  return $match.OutputValue
}

$foundationOutputs = Get-StackOutputMap $FoundationStackName
$computeOutputs = Get-StackOutputMap $ComputeStackName

$privateSubnetIds = Get-Output $foundationOutputs "PrivateSubnetIds"
$ecsServiceSecurityGroupId = Get-Output $foundationOutputs "EcsServiceSecurityGroupId"
$clusterName = Get-Output $computeOutputs "ClusterName"
$capacityProviderName = Get-Output $computeOutputs "CapacityProviderName"

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    ClusterName=$clusterName `
    CapacityProviderName=$capacityProviderName `
    SubnetIds=$privateSubnetIds `
    EcsServiceSecurityGroupId=$ecsServiceSecurityGroupId `
    DesiredCount=$DesiredCount

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
