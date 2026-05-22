param(
  [switch]$Apply,
  [string]$StackName = "atomic-radius-acm-certificates",
  [string]$DnsStackName = "atomic-radius-dns-zone",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$DomainName = "atomicradius.app",
  [string]$Region = "us-east-1",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "acm-certificates.yaml"

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
  Write-Host "Dry run only. Re-run with -Apply after the hosted zone exists to request the ACM certificate."
  return
}

$dnsOutputs = & aws @awsArgs cloudformation describe-stacks `
  --stack-name $DnsStackName `
  --query "Stacks[0].Outputs" `
  --output json | ConvertFrom-Json

$hostedZoneOutput = $dnsOutputs | Where-Object { $_.OutputKey -eq "HostedZoneId" } | Select-Object -First 1
if (-not $hostedZoneOutput) {
  throw "Missing HostedZoneId output from $DnsStackName."
}

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    DomainName=$DomainName `
    HostedZoneId=$($hostedZoneOutput.OutputValue)

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
