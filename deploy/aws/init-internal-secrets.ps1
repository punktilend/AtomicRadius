param(
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

function New-SecretValue {
  param([int]$Bytes = 48)

  $buffer = [byte[]]::new($Bytes)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
  return [Convert]::ToBase64String($buffer).TrimEnd("=") -replace "\+", "-" -replace "/", "_"
}

function Put-SecretIfMissing {
  param(
    [string]$Name,
    [int]$Bytes = 48
  )

  $exists = $true
  & aws @awsArgs ssm get-parameter --name $Name --with-decryption *> $null
  if ($LASTEXITCODE -ne 0) {
    $exists = $false
    $global:LASTEXITCODE = 0
  }

  if ($exists) {
    Write-Host "exists $Name"
    return
  }

  $value = New-SecretValue -Bytes $Bytes
  & aws @awsArgs ssm put-parameter `
    --name $Name `
    --type SecureString `
    --value $value `
    --description "Generated internal Atomic Radius $EnvironmentName secret." `
    --no-overwrite | Out-Null

  Write-Host "created $Name"
}

$prefix = "/$ProjectName/$EnvironmentName/secrets"

Put-SecretIfMissing "$prefix/secret_key_base" 64
Put-SecretIfMissing "$prefix/sudo_mode_secret" 48
Put-SecretIfMissing "$prefix/gateway_rpc_secret" 48
Put-SecretIfMissing "$prefix/gateway_admin_secret" 48
Put-SecretIfMissing "$prefix/erlang_cookie" 32
Put-SecretIfMissing "$prefix/media_proxy_secret_key" 48
