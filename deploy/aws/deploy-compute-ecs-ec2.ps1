param(
  [string]$StackName = "atomic-radius-compute-ecs-ec2",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$InstanceType = "t3.medium",
  [int]$DesiredCapacity = 0,
  [int]$MinSize = 0,
  [int]$MaxSize = 3,
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "compute-ecs-ec2.yaml"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

$outputs = & aws @awsArgs cloudformation describe-stacks `
  --stack-name $FoundationStackName `
  --query "Stacks[0].Outputs" `
  --output json | ConvertFrom-Json

function Get-FoundationOutput {
  param([string]$Key)
  $match = $outputs | Where-Object { $_.OutputKey -eq $Key } | Select-Object -First 1
  if (-not $match) {
    throw "Missing foundation output: $Key"
  }
  return $match.OutputValue
}

$vpcId = Get-FoundationOutput "VpcId"
$publicSubnetIds = Get-FoundationOutput "PublicSubnetIds"
$ecsServiceSecurityGroupId = Get-FoundationOutput "EcsServiceSecurityGroupId"

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    VpcId=$vpcId `
    SubnetIds=$publicSubnetIds `
    EcsServiceSecurityGroupId=$ecsServiceSecurityGroupId `
    InstanceType=$InstanceType `
    DesiredCapacity=$DesiredCapacity `
    MinSize=$MinSize `
    MaxSize=$MaxSize

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
