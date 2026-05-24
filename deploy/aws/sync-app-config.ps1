param(
  [string]$FoundationStackName = "atomic-radius-foundation",
  [string]$ProjectName = "atomic-radius",
  [string]$EnvironmentName = "prod",
  [string]$AppEndpoint = "https://atomicradius.app",
  [string]$ApiPublicEndpoint = "https://atomicradius.app/api",
  [string]$ApiClientEndpoint = "https://atomicradius.app/api",
  [string]$GatewayEndpoint = "wss://gateway.atomicradius.app",
  [string]$MediaEndpoint = "https://atomicradius.app/media",
  [string]$CdnEndpoint = "https://atomicradius.app",
  [string]$MarketingEndpoint = "https://atomicradius.app",
  [string]$AdminEndpoint = "https://atomicradius.app",
  [string]$InviteEndpoint = "https://atomicradius.app/invite",
  [string]$GiftEndpoint = "https://atomicradius.app/gift",
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
  $jsonPath = Join-Path ([System.IO.Path]::GetTempPath()) ("atomic-radius-ssm-{0}.json" -f ([System.Guid]::NewGuid()))
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

$prefix = "/$ProjectName/$EnvironmentName/config"

$config = @{
  "NODE_ENV" = "production"
  "FLUXER_API_PORT" = "8080"
  "FLUXER_GATEWAY_WS_PORT" = "8080"
  "FLUXER_GATEWAY_RPC_PORT" = "8081"
  "FLUXER_MEDIA_PROXY_PORT" = "8080"
  "FLUXER_ADMIN_PORT" = "8080"
  "FLUXER_MARKETING_PORT" = "8080"
  "FLUXER_PATH_GATEWAY" = "/gateway"
  "FLUXER_PATH_ADMIN" = "/admin"
  "FLUXER_PATH_MARKETING" = "/"
  "FLUXER_API_PUBLIC_ENDPOINT" = $ApiPublicEndpoint
  "FLUXER_API_CLIENT_ENDPOINT" = $ApiClientEndpoint
  # Marketing can render without API RPC; keep this local until service discovery is added.
  "FLUXER_API_HOST" = "127.0.0.1:9"
  "FLUXER_APP_ENDPOINT" = $AppEndpoint
  "FLUXER_GATEWAY_ENDPOINT" = $GatewayEndpoint
  "FLUXER_MEDIA_ENDPOINT" = $MediaEndpoint
  "FLUXER_CDN_ENDPOINT" = $CdnEndpoint
  "FLUXER_MARKETING_ENDPOINT" = $MarketingEndpoint
  "FLUXER_ADMIN_ENDPOINT" = $AdminEndpoint
  "FLUXER_INVITE_ENDPOINT" = $InviteEndpoint
  "FLUXER_GIFT_ENDPOINT" = $GiftEndpoint
  "ADMIN_OAUTH2_AUTO_CREATE" = "false"
  "ADMIN_OAUTH2_REDIRECT_URI" = "$AdminEndpoint/oauth2_callback"
  "PASSKEYS_ENABLED" = "true"
  "PASSKEY_RP_NAME" = "Atomic Radius"
  "PASSKEY_RP_ID" = "atomicradius.app"
  "PASSKEY_ALLOWED_ORIGINS" = $AppEndpoint
  "EMAIL_ENABLED" = "false"
  "SMS_ENABLED" = "false"
  "CAPTCHA_ENABLED" = "false"
  "CAPTCHA_PRIMARY_PROVIDER" = "none"
  "SEARCH_ENABLED" = "false"
  "STRIPE_ENABLED" = "false"
  "VOICE_ENABLED" = "false"
  "CLAMAV_ENABLED" = "false"
  "CLAMAV_FAIL_OPEN" = "true"
  "CLOUDFLARE_PURGE_ENABLED" = "false"
  "METRICS_MODE" = "noop"
  "SELF_HOSTED" = "true"
  "RELEASE_CHANNEL" = "stable"
  "AWS_S3_BUCKET_CDN" = Get-FoundationOutput "StaticBucketName"
  "AWS_S3_BUCKET_STATIC" = Get-FoundationOutput "StaticBucketName"
  "AWS_S3_BUCKET_UPLOADS" = Get-FoundationOutput "UploadsBucketName"
  "AWS_S3_BUCKET_REPORTS" = Get-FoundationOutput "ReportsBucketName"
  "AWS_S3_BUCKET_HARVESTS" = Get-FoundationOutput "HarvestsBucketName"
  "AWS_S3_BUCKET_DOWNLOADS" = Get-FoundationOutput "DownloadsBucketName"
}

foreach ($key in ($config.Keys | Sort-Object)) {
  Put-StringParameter `
    -Name "$prefix/$key" `
    -Value $config[$key] `
    -Description "Atomic Radius $EnvironmentName runtime config: $key."
}
