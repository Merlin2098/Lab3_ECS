param()

$outputs     = terraform -chdir=infra output -json | ConvertFrom-Json
$execRoleArn = $outputs.task_execution_role_arn.value
$taskRoleArn = $outputs.task_role_arn.value

function Test-RoleAssumable {
  param([string]$RoleArn)

  $roleName = $RoleArn -replace ".*role/", ""
  $role     = aws iam get-role --role-name $roleName | ConvertFrom-Json

  if (-not $role.Role) {
    Write-Error "Rol no encontrado: $roleName"
    return $false
  }

  $trust    = ($role.Role.AssumeRolePolicyDocument | ConvertFrom-Json)
  $services = $trust.Statement | ForEach-Object { $_.Principal.Service }

  if ("ecs-tasks.amazonaws.com" -notin $services) {
    Write-Error "$roleName no es asumible por ecs-tasks.amazonaws.com"
    return $false
  }

  Write-Host "IAM OK: $roleName → asumible por ecs-tasks.amazonaws.com"
  return $true
}

$ok  = Test-RoleAssumable -RoleArn $execRoleArn
$ok2 = Test-RoleAssumable -RoleArn $taskRoleArn

if (-not ($ok -and $ok2)) { exit 1 }
Write-Host "smoke_iam: OK"
