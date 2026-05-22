param(
  [string]$ImageTag = "local",
  [string]$Region = "us-east-1",
  [string]$AccountId = "817378414866",
  [string]$Profile = ""
)

$ErrorActionPreference = "Stop"

$awsArgs = @()
if ($Profile) {
  $awsArgs += @("--profile", $Profile)
}

$registry = "$AccountId.dkr.ecr.$Region.amazonaws.com"

& aws @awsArgs ecr get-login-password --region $Region | docker login --username AWS --password-stdin $registry
if ($LASTEXITCODE -ne 0) {
  throw "Failed to login to ECR."
}

$images = @(
  @{ Repository = "atomic-radius-api"; Context = "fluxer_api"; Dockerfile = "fluxer_api/Dockerfile" },
  @{ Repository = "atomic-radius-api-worker"; Context = "fluxer_api"; Dockerfile = "fluxer_api/Dockerfile" },
  @{ Repository = "atomic-radius-gateway"; Context = "fluxer_gateway"; Dockerfile = "fluxer_gateway/Dockerfile" },
  @{ Repository = "atomic-radius-media-proxy"; Context = "fluxer_media_proxy"; Dockerfile = "fluxer_media_proxy/Dockerfile" },
  @{ Repository = "atomic-radius-admin"; Context = "fluxer_admin"; Dockerfile = "fluxer_admin/Dockerfile" },
  @{ Repository = "atomic-radius-marketing"; Context = "fluxer_marketing"; Dockerfile = "fluxer_marketing/Dockerfile" },
  @{ Repository = "atomic-radius-docs"; Context = "fluxer_docs"; Dockerfile = "fluxer_docs/Dockerfile" },
  @{ Repository = "atomic-radius-metrics"; Context = "fluxer_metrics"; Dockerfile = "fluxer_metrics/Dockerfile" }
)

foreach ($image in $images) {
  $uri = "$registry/$($image.Repository):$ImageTag"
  docker build --platform linux/amd64 -t $uri -f $image.Dockerfile $image.Context
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to build $uri."
  }

  docker push $uri
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to push $uri."
  }
}
