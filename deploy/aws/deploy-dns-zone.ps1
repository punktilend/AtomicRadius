param(
  [switch]$Apply,
  [string]$StackName = "atomic-radius-dns-zone",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$DomainName = "atomicradius.app",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "dns-zone.yaml"

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
  Write-Host "Dry run only. Re-run with -Apply to create the Route 53 hosted zone."
  return
}

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    DomainName=$DomainName

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
