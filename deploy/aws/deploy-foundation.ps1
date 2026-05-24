param(
  [string]$StackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "foundation.yaml"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
