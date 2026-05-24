param(
  [string]$StackName = "atomic-radius-ecs-services-fargate-zero",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$ClusterName = "atomic-radius-prod",
  [int]$DesiredCount = 0,
  [string]$Region = "",
  [string]$Profile = "",
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "ecs-services-fargate-zero.yaml"

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

$publicSubnetIds = Get-FoundationOutput "PublicSubnetIds"
$ecsServiceSecurityGroupId = Get-FoundationOutput "EcsServiceSecurityGroupId"

if (-not $Apply) {
  & aws @awsArgs cloudformation validate-template --template-body "file://$template" | Out-Host
  Write-Host "Dry run only. Add -Apply to create zero-count Fargate fallback services."
  return
}

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    ClusterName=$ClusterName `
    SubnetIds=$publicSubnetIds `
    EcsServiceSecurityGroupId=$ecsServiceSecurityGroupId `
    DesiredCount=$DesiredCount

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
