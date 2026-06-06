param(
  [string]$Region = $env:AWS_DEFAULT_REGION ?? "us-east-1"
)

$outputs  = terraform -chdir=infra output -json | ConvertFrom-Json
$logGroup = $outputs.log_group_name.value

$groups = aws logs describe-log-groups --log-group-name-prefix $logGroup --region $Region | ConvertFrom-Json

if ($groups.logGroups.Count -eq 0) {
  Write-Error "Log Group no encontrado: $logGroup"
  exit 1
}

$retention = $groups.logGroups[0].retentionInDays
if (-not $retention) {
  Write-Error "Log Group sin retention_in_days configurado: $logGroup"
  exit 1
}

Write-Host "CloudWatch Log Group OK: $logGroup (retención: $retention días)"
