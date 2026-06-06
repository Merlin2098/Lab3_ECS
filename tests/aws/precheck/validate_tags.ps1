param(
  [string]$Project = $env:TF_VAR_project_name  ?? "ecs-terraform-lab",
  [string]$Region  = $env:AWS_DEFAULT_REGION    ?? "us-east-1"
)

$required = @("Project", "Environment", "Owner", "ManagedBy", "CostCenter")

$resources = aws resourcegroupstaggingapi get-resources `
  --tag-filters "Key=Project,Values=$Project" `
  --region $Region | ConvertFrom-Json

if ($resources.ResourceTagMappingList.Count -eq 0) {
  Write-Warning "No se encontraron recursos con tag Project=$Project en $Region"
  Write-Warning "Asegurarse de activar Cost Allocation Tags en la consola de Billing."
  exit 0
}

$errors = 0
foreach ($r in $resources.ResourceTagMappingList) {
  $tagKeys = $r.Tags | ForEach-Object { $_.Key }
  $missing = $required | Where-Object { $_ -notin $tagKeys }
  if ($missing) {
    Write-Warning "$($r.ResourceARN) falta tags: $($missing -join ', ')"
    $errors++
  }
}

if ($errors -gt 0) { Write-Error "validate_tags: $errors recursos con tags faltantes"; exit 1 }
Write-Host "validate_tags: OK ($($resources.ResourceTagMappingList.Count) recursos revisados)"
