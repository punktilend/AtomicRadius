param(
  [string]$Profile = "",
  [string]$Region = ""
)

$ErrorActionPreference = "Stop"

function Invoke-AwsJson {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $baseArgs = @()
  if ($Profile) {
    $baseArgs += @("--profile", $Profile)
  }
  if ($Region) {
    $baseArgs += @("--region", $Region)
  }

  $raw = & aws @baseArgs @Arguments 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    return $null
  }

  return $raw | ConvertFrom-Json
}

$identity = Invoke-AwsJson @("sts", "get-caller-identity")
$resolvedRegion = if ($Region) { $Region } else { (& aws configure get region) }

Write-Host "AWS identity"
$identity | ConvertTo-Json -Depth 5
Write-Host ""
Write-Host "Region: $resolvedRegion"
Write-Host ""

Write-Host "S3 buckets"
& aws $(if ($Profile) { @("--profile", $Profile) } else { @() }) s3 ls
Write-Host ""

Write-Host "VPCs"
$vpcs = Invoke-AwsJson @("ec2", "describe-vpcs")
$vpcs.Vpcs | Select-Object VpcId, IsDefault, State, CidrBlock | Format-Table -AutoSize
Write-Host ""

Write-Host "ECR repositories"
$repos = Invoke-AwsJson @("ecr", "describe-repositories")
if ($repos -and $repos.repositories) {
  $repos.repositories | Select-Object repositoryName, repositoryUri, createdAt | Format-Table -AutoSize
} else {
  Write-Host "None"
}
Write-Host ""

Write-Host "ECS clusters"
$clusters = Invoke-AwsJson @("ecs", "list-clusters")
if ($clusters -and $clusters.clusterArns) {
  $clusters.clusterArns
  foreach ($clusterArn in $clusters.clusterArns) {
    $services = Invoke-AwsJson @("ecs", "list-services", "--cluster", $clusterArn)
    if ($services -and $services.serviceArns) {
      Write-Host ""
      Write-Host "ECS services for $clusterArn"
      $serviceArgs = @("ecs", "describe-services", "--cluster", $clusterArn, "--services") + $services.serviceArns
      $serviceDetails = Invoke-AwsJson $serviceArgs
      $serviceDetails.services | Select-Object serviceName, status, desiredCount, runningCount, pendingCount | Format-Table -AutoSize
    }
  }
} else {
  Write-Host "None"
}
Write-Host ""

Write-Host "Auto Scaling Groups"
$asgs = Invoke-AwsJson @("autoscaling", "describe-auto-scaling-groups")
if ($asgs -and $asgs.AutoScalingGroups) {
  $asgs.AutoScalingGroups | Select-Object AutoScalingGroupName, MinSize, DesiredCapacity, MaxSize | Format-Table -AutoSize
} else {
  Write-Host "None"
}
Write-Host ""

Write-Host "RDS instances"
$rds = Invoke-AwsJson @("rds", "describe-db-instances")
if ($rds -and $rds.DBInstances) {
  $rds.DBInstances | Select-Object DBInstanceIdentifier, Engine, DBInstanceStatus, DBInstanceClass, MultiAZ | Format-Table -AutoSize
} else {
  Write-Host "None"
}
Write-Host ""

Write-Host "ElastiCache clusters"
$cache = Invoke-AwsJson @("elasticache", "describe-cache-clusters")
if ($cache -and $cache.CacheClusters) {
  $cache.CacheClusters | Select-Object CacheClusterId, Engine, CacheClusterStatus, CacheNodeType | Format-Table -AutoSize
} else {
  Write-Host "None"
}
