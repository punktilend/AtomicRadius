param(
  [switch]$Apply,
  [string]$StackName = "atomic-radius-scylla-ec2",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "scylla-ec2.yaml"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

& aws @awsArgs cloudformation validate-template --template-body "file://$template" | Out-Null
Write-Host "Validated $template"

if (-not $Apply) {
  Write-Host "Dry run only. Re-run with -Apply to create billable EC2/EBS Scylla resources."
  return
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
$privateSubnetId = (Get-FoundationOutput "PrivateSubnetIds").Split(",")[0]
$dataSecurityGroupId = Get-FoundationOutput "DataSecurityGroupId"

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    VpcId=$vpcId `
    PrivateSubnetId=$privateSubnetId `
    DataSecurityGroupId=$dataSecurityGroupId

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
