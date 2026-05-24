param(
  [string]$DomainName = "atomicradius.app",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "us-east-1",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}

$hostedZones = & aws @awsArgs route53 list-hosted-zones-by-name `
  --dns-name $DomainName `
  --query "HostedZones[?Name=='$DomainName.'].{Id:Id,Name:Name,Private:Config.PrivateZone}" `
  --output table

Write-Host "Hosted zones"
$hostedZones
Write-Host ""

$certs = & aws @awsArgs acm list-certificates `
  --region $Region `
  --query "CertificateSummaryList[?DomainName=='$DomainName'].{DomainName:DomainName,Arn:CertificateArn,Status:Status}" `
  --output table

Write-Host "ACM certificates"
$certs
Write-Host ""

$prefix = "/$ProjectName/$EnvironmentName/dns"
$params = & aws @awsArgs ssm get-parameters-by-path `
  --path $prefix `
  --recursive `
  --query "Parameters[].{Name:Name,Value:Value}" `
  --output table 2>$null

Write-Host "SSM DNS parameters"
if ($LASTEXITCODE -eq 0 -and $params) {
  $params
} else {
  Write-Host "None"
}
