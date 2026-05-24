param(
  [string]$DnsStackName = "atomic-radius-dns-zone",
  [string]$AcmStackName = "atomic-radius-acm-certificates",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$Region = "",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}
if ($Region) {
  $awsArgs += @("--region", $Region)
}

function Get-StackOutputs {
  param([string]$StackName)
  return & aws @awsArgs cloudformation describe-stacks `
    --stack-name $StackName `
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

function Put-StringParameter {
  param(
    [string]$Name,
    [string]$Value,
    [string]$Description
  )

  $payload = @{
    Name = $Name
    Type = "String"
    Value = $Value
    Description = $Description
    Overwrite = $true
  }
  $jsonPath = Join-Path ([System.IO.Path]::GetTempPath()) ("atomic-radius-dns-ssm-{0}.json" -f ([System.Guid]::NewGuid()))
  try {
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -NoNewline
    & aws @awsArgs ssm put-parameter --cli-input-json "file://$jsonPath" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to put SSM parameter $Name."
    }
  } finally {
    Remove-Item -LiteralPath $jsonPath -Force -ErrorAction SilentlyContinue
  }

  Write-Host $Name
}

$prefix = "/$ProjectName/$EnvironmentName/dns"

$dnsOutputs = Get-StackOutputs $DnsStackName
Put-StringParameter "$prefix/hosted_zone_id" (Get-Output $dnsOutputs "HostedZoneId") "Atomic Radius hosted zone ID."
Put-StringParameter "$prefix/domain_name" (Get-Output $dnsOutputs "HostedZoneName") "Atomic Radius domain name."
Put-StringParameter "$prefix/name_servers" (Get-Output $dnsOutputs "NameServers") "Atomic Radius hosted zone name servers."

try {
  $acmOutputs = Get-StackOutputs $AcmStackName
  $certificateArn = Get-Output $acmOutputs "CertificateArn"
} catch {
  $domainName = Get-Output $dnsOutputs "HostedZoneName"
  $certificateArn = & aws @awsArgs acm list-certificates `
    --region us-east-1 `
    --query "CertificateSummaryList[?DomainName=='$domainName'].CertificateArn | [0]" `
    --output text

  if (-not $certificateArn -or $certificateArn -eq "None") {
    throw "Missing certificate ARN from $AcmStackName and ACM list-certificates."
  }
}

Put-StringParameter "$prefix/certificate_arn" $certificateArn "Atomic Radius ACM certificate ARN."
