param(
  [string]$Project = $env:TF_VAR_project_name ?? "ecs-terraform-lab",
  [string]$Env     = $env:TF_VAR_environment   ?? "dev"
)

$outputs = terraform -chdir=infra output -json | ConvertFrom-Json

$execRoleArn = $outputs.task_execution_role_arn.value
$taskRoleArn = $outputs.task_role_arn.value

function Test-Role {
  param([string]$RoleArn, [string]$Label)

  $roleName = $RoleArn -replace ".*role/", ""
  Write-Host "Validando $Label`: $roleName"

  $role = aws iam get-role --role-name $roleName | ConvertFrom-Json
  if (-not $role) { Write-Error "Rol no encontrado: $roleName"; exit 1 }

  $trust = ($role.Role.AssumeRolePolicyDocument | ConvertFrom-Json)
  $services = $trust.Statement | ForEach-Object { $_.Principal.Service }
  if ("ecs-tasks.amazonaws.com" -notin $services) {
    Write-Error "$Label no tiene trust policy hacia ecs-tasks.amazonaws.com"
    exit 1
  }
  Write-Host "  Trust policy OK: $($services -join ', ')"

  $policies = aws iam list-attached-role-policies --role-name $roleName | ConvertFrom-Json
  Write-Host "  Policies adjuntas: $($policies.AttachedPolicies.PolicyName -join ', ')"
}

Test-Role -RoleArn $execRoleArn -Label "Task Execution Role"
Test-Role -RoleArn $taskRoleArn -Label "Task Role"

Write-Host "validate_iam: OK"
