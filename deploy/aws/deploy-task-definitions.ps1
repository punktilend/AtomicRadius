param(
  [string]$StackName = "atomic-radius-task-definitions",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$ImageTag = "main",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "task-definitions.yaml"

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

$taskExecutionRoleArn = Get-FoundationOutput "EcsTaskExecutionRoleArn"
$taskRoleArn = Get-FoundationOutput "EcsTaskRoleArn"

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    ImageTag=$ImageTag `
    EcsTaskExecutionRoleArn=$taskExecutionRoleArn `
    EcsTaskRoleArn=$taskRoleArn

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
