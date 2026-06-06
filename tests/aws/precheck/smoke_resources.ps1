param(
  [string]$Region = $env:AWS_DEFAULT_REGION ?? "us-east-1"
)

$outputs = terraform -chdir=infra output -json | ConvertFrom-Json

# ECR
$repoName = $outputs.repository_name.value
$repos = aws ecr describe-repositories --repository-names $repoName --region $Region 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "ECR repositorio no encontrado: $repoName"; exit 1 }
Write-Host "ECR OK: $repoName"

# ECS Cluster
$clusterName = $outputs.cluster_name.value
$clusters = aws ecs describe-clusters --clusters $clusterName --region $Region | ConvertFrom-Json
if ($clusters.clusters[0].status -ne "ACTIVE") {
  Write-Error "ECS Cluster no activo: $clusterName (status: $($clusters.clusters[0].status))"
  exit 1
}
Write-Host "ECS Cluster OK: $clusterName (ACTIVE)"

# ECS Service
$serviceName = $outputs.service_name.value
$services = aws ecs describe-services --cluster $clusterName --services $serviceName --region $Region | ConvertFrom-Json
if ($services.services[0].status -ne "ACTIVE") {
  Write-Error "ECS Service no activo: $serviceName"
  exit 1
}
Write-Host "ECS Service OK: $serviceName (ACTIVE)"

# CloudWatch Log Group
$logGroup = $outputs.log_group_name.value
$logs = aws logs describe-log-groups --log-group-name-prefix $logGroup --region $Region | ConvertFrom-Json
if ($logs.logGroups.Count -eq 0) {
  Write-Error "Log Group no encontrado: $logGroup"
  exit 1
}
Write-Host "CloudWatch Log Group OK: $logGroup"

Write-Host "smoke_resources: OK"
