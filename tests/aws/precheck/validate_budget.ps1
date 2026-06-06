param(
  [string]$AccountId = (aws sts get-caller-identity | ConvertFrom-Json).Account,
  [string]$Project   = $env:TF_VAR_project_name ?? "ecs-terraform-lab"
)

$budgets = aws budgets describe-budgets --account-id $AccountId | ConvertFrom-Json

if ($budgets.Budgets.Count -eq 0) {
  Write-Error "No se encontraron AWS Budgets. Ejecutar terraform apply primero."
  exit 1
}

$projectBudgets = $budgets.Budgets | Where-Object { $_.BudgetName -like "*$Project*" }
if ($projectBudgets.Count -eq 0) {
  Write-Warning "No hay budgets con nombre que contenga '$Project'. Budgets existentes: $($budgets.Budgets.BudgetName -join ', ')"
} else {
  Write-Host "Budgets del proyecto: $($projectBudgets.BudgetName -join ', ')"
}

Write-Host "validate_budget: OK"
