param(
  [string]$FoundationStackName = "atomic-radius-foundation",
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

$resolvedRegion = if ($Region) { $Region } else { (& aws @awsArgs configure get region) }
if (-not $resolvedRegion) {
  $resolvedRegion = "us-east-1"
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

  & aws @awsArgs ssm put-parameter `
    --name $Name `
    --type String `
    --value $Value `
    --description $Description `
    --overwrite | Out-Null

  Write-Host $Name
}

$prefix = "/$ProjectName/$EnvironmentName"

$parameters = @(
  @{ Name = "$prefix/aws/region"; Value = $resolvedRegion; Description = "AWS region for Atomic Radius $EnvironmentName." },
  @{ Name = "$prefix/network/vpc_id"; Value = Get-FoundationOutput "VpcId"; Description = "Atomic Radius VPC ID." },
  @{ Name = "$prefix/network/public_subnet_ids"; Value = Get-FoundationOutput "PublicSubnetIds"; Description = "Comma-separated public subnet IDs." },
  @{ Name = "$prefix/network/private_subnet_ids"; Value = Get-FoundationOutput "PrivateSubnetIds"; Description = "Comma-separated private subnet IDs." },
  @{ Name = "$prefix/security/alb_security_group_id"; Value = Get-FoundationOutput "AlbSecurityGroupId"; Description = "ALB security group ID." },
  @{ Name = "$prefix/security/ecs_service_security_group_id"; Value = Get-FoundationOutput "EcsServiceSecurityGroupId"; Description = "ECS service security group ID." },
  @{ Name = "$prefix/security/data_security_group_id"; Value = Get-FoundationOutput "DataSecurityGroupId"; Description = "Data service security group ID." },
  @{ Name = "$prefix/iam/ecs_task_execution_role_arn"; Value = Get-FoundationOutput "EcsTaskExecutionRoleArn"; Description = "ECS task execution role ARN." },
  @{ Name = "$prefix/iam/ecs_task_role_arn"; Value = Get-FoundationOutput "EcsTaskRoleArn"; Description = "ECS task role ARN." },
  @{ Name = "$prefix/s3/static_bucket"; Value = Get-FoundationOutput "StaticBucketName"; Description = "Static object bucket name." },
  @{ Name = "$prefix/s3/uploads_bucket"; Value = Get-FoundationOutput "UploadsBucketName"; Description = "Uploads object bucket name." },
  @{ Name = "$prefix/s3/reports_bucket"; Value = Get-FoundationOutput "ReportsBucketName"; Description = "Reports object bucket name." },
  @{ Name = "$prefix/s3/harvests_bucket"; Value = Get-FoundationOutput "HarvestsBucketName"; Description = "Harvests object bucket name." },
  @{ Name = "$prefix/s3/downloads_bucket"; Value = Get-FoundationOutput "DownloadsBucketName"; Description = "Downloads object bucket name." },
  @{ Name = "$prefix/ecr/api_repository_uri"; Value = Get-FoundationOutput "ApiRepositoryUri"; Description = "API ECR repository URI." },
  @{ Name = "$prefix/ecr/gateway_repository_uri"; Value = Get-FoundationOutput "GatewayRepositoryUri"; Description = "Gateway ECR repository URI." },
  @{ Name = "$prefix/ecr/media_proxy_repository_uri"; Value = Get-FoundationOutput "MediaProxyRepositoryUri"; Description = "Media proxy ECR repository URI." }
)

foreach ($parameter in $parameters) {
  Put-StringParameter `
    -Name $parameter.Name `
    -Value $parameter.Value `
    -Description $parameter.Description
}
