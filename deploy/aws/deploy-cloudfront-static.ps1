param(
  [switch]$Apply,
  [string]$StackName = "atomic-radius-cloudfront-static",
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$StaticDomainName = "",
  [string]$CertificateArn = "",
  [string]$DnsParameterPrefix = "/atomic-radius/prod/dns",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $scriptDir "cloudfront-static.yaml"

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
  Write-Host "Dry run only. Re-run with -Apply to create billable CloudFront resources."
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

$staticBucketName = Get-FoundationOutput "StaticBucketName"

if (-not $CertificateArn) {
  $CertificateArn = & aws @awsArgs ssm get-parameter `
    --name "$DnsParameterPrefix/certificate_arn" `
    --query "Parameter.Value" `
    --output text 2>$null
  if ($LASTEXITCODE -ne 0 -or $CertificateArn -eq "None") {
    $CertificateArn = ""
    $global:LASTEXITCODE = 0
  }
}

& aws @awsArgs cloudformation deploy `
  --stack-name $StackName `
  --template-file $template `
  --parameter-overrides `
    ProjectName=$ProjectName `
    EnvironmentName=$EnvironmentName `
    StaticBucketName=$staticBucketName `
    StaticDomainName=$StaticDomainName `
    CertificateArn=$CertificateArn

if ($LASTEXITCODE -ne 0) {
  throw "CloudFormation deploy failed."
}

& aws @awsArgs cloudformation describe-stacks `
  --stack-name $StackName `
  --query "Stacks[0].Outputs" `
  --output table
