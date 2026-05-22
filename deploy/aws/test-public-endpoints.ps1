param(
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$ApiEndpoint = "",
  [string]$MediaEndpoint = "",
  [string]$AdminEndpoint = "",
  [string]$MarketingEndpoint = "",
  [string]$DocsEndpoint = "",
  [string]$MetricsEndpoint = "",
  [int]$TimeoutSeconds = 10,
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

function Get-ConfigParameter {
  param([string]$Name)

  $value = & aws @awsArgs ssm get-parameter `
    --name "/$ProjectName/$EnvironmentName/config/$Name" `
    --query "Parameter.Value" `
    --output text 2>$null

  if ($LASTEXITCODE -ne 0 -or -not $value -or $value -eq "None") {
    return ""
  }

  return $value.TrimEnd("/")
}

function Join-EndpointPath {
  param(
    [string]$Endpoint,
    [string]$Path
  )

  if (-not $Endpoint) {
    return ""
  }

  return "{0}{1}" -f $Endpoint.TrimEnd("/"), $Path
}

if (-not $ApiEndpoint) {
  $ApiEndpoint = Get-ConfigParameter "FLUXER_API_PUBLIC_ENDPOINT"
}
if (-not $MediaEndpoint) {
  $MediaEndpoint = Get-ConfigParameter "FLUXER_MEDIA_ENDPOINT"
}
if (-not $AdminEndpoint) {
  $AdminEndpoint = Get-ConfigParameter "FLUXER_ADMIN_ENDPOINT"
}
if (-not $MarketingEndpoint) {
  $MarketingEndpoint = Get-ConfigParameter "FLUXER_MARKETING_ENDPOINT"
}
if (-not $DocsEndpoint) {
  $DocsEndpoint = Get-ConfigParameter "FLUXER_DOCS_ENDPOINT"
}
if (-not $MetricsEndpoint) {
  $MetricsEndpoint = Get-ConfigParameter "FLUXER_METRICS_ENDPOINT"
}

$checks = @(
  @{ Name = "api"; Url = Join-EndpointPath $ApiEndpoint "/_health"; ExpectedStatus = 200 },
  @{ Name = "media"; Url = Join-EndpointPath $MediaEndpoint "/_health"; ExpectedStatus = 200 },
  @{ Name = "admin"; Url = Join-EndpointPath $AdminEndpoint "/"; ExpectedStatus = 200 },
  @{ Name = "marketing"; Url = Join-EndpointPath $MarketingEndpoint "/"; ExpectedStatus = 200 },
  @{ Name = "docs"; Url = Join-EndpointPath $DocsEndpoint "/"; ExpectedStatus = 200 },
  @{ Name = "metrics"; Url = Join-EndpointPath $MetricsEndpoint "/_health"; ExpectedStatus = 200 }
)

$failures = @()
foreach ($check in $checks) {
  if (-not $check.Url) {
    Write-Host ("{0,-10} SKIP no endpoint configured" -f $check.Name)
    continue
  }

  try {
    $response = Invoke-WebRequest `
      -Uri $check.Url `
      -Method GET `
      -TimeoutSec $TimeoutSeconds `
      -MaximumRedirection 0 `
      -SkipHttpErrorCheck

    $status = [int]$response.StatusCode
    if ($status -eq $check.ExpectedStatus) {
      Write-Host ("{0,-10} OK   {1} {2}" -f $check.Name, $status, $check.Url)
    } else {
      Write-Host ("{0,-10} FAIL {1} {2}" -f $check.Name, $status, $check.Url)
      $failures += $check.Name
    }
  } catch {
    Write-Host ("{0,-10} FAIL {1}" -f $check.Name, $_.Exception.Message)
    $failures += $check.Name
  }
}

if ($failures.Count -gt 0) {
  throw "Endpoint smoke tests failed: $($failures -join ', ')"
}
