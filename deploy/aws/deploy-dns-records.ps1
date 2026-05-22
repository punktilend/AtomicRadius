param(
  [switch]$Apply,
  [string]$StackName = "atomic-radius-dns-records",
  [string]$DnsStackName = "atomic-radius-dns-zone",
  [string]$EdgeStackName = "atomic-radius-edge-alb",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$DomainName = "atomicradius.app",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "dns-records.yaml"

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
  Write-Host "Dry run only. Re-run with -Apply to create Route 53 ALB alias records."
  return
}

function Get-StackOutputs {
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

$dnsOutputs = Get-StackOutputs $DnsStackName
$edgeOutputs = Get-StackOutputs $EdgeStackName

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    DomainName=$DomainName `
    HostedZoneId=$(Get-Output $dnsOutputs "HostedZoneId") `
    LoadBalancerDnsName=$(Get-Output $edgeOutputs "LoadBalancerDnsName") `
    LoadBalancerHostedZoneId=$(Get-Output $edgeOutputs "LoadBalancerHostedZoneId")

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
