param(
  [switch]$Apply,
  [string]$StackName = "atomic-radius-data-services",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "data-services.yaml"

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
  Write-Host "Dry run only. Re-run with -Apply to create billable RDS and ElastiCache resources."
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
$privateSubnetIds = Get-FoundationOutput "PrivateSubnetIds"
$dataSecurityGroupId = Get-FoundationOutput "DataSecurityGroupId"

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    VpcId=$vpcId `
    PrivateSubnetIds=$privateSubnetIds `
    DataSecurityGroupId=$dataSecurityGroupId

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
