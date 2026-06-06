# 02 — Levantar la infraestructura ECS

Despliega ECR, ECS Cluster, ECS Service, IAM, CloudWatch y Networking.
Ejecutar **después** de completar `01_backend_bootstrap.md`.

> **Workflow completo:**
> `01_backend_bootstrap` → `02_infra_deploy` (Paso 1: terraform apply) → `01.5_docker_push` → `02_infra_deploy` (Paso 2: verificar)

---

## Windows (PowerShell)

### Paso 0 — Cargar credenciales AWS

```powershell
Get-Content infra\env\.env.credentials | ForEach-Object {
  if ($_ -match "^\s*#" -or $_ -match "^\s*$") { return }

  $name, $value = $_ -split "=", 2
  [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), "Process")
}

# Verificar
aws sts get-caller-identity
```

### Paso 1 — Desplegar la infraestructura

```powershell
# Ir a infra/ guardando la ubicación actual
Push-Location infra

# Inicializar Terraform con el backend S3
terraform init

# Revisar el plan completo
terraform plan

# Aplicar (tarda ~2-4 min; crea el repositorio ECR entre otros recursos)
terraform apply

# Ver los outputs del despliegue
terraform output

# Volver al directorio anterior
Pop-Location
```

> Una vez completado, el repositorio ECR ya existe.
> Continuar con **`01.5_docker_push.md`** para subir la imagen, luego volver al Paso 2.

---

### Paso 2 — Verificar el despliegue

```powershell
Push-Location infra

# Capturar outputs
$CLUSTER   = terraform output -raw cluster_name
$SERVICE   = terraform output -raw service_name
$LOG_GROUP = terraform output -raw log_group_name

# Estado del servicio ECS
aws ecs describe-services `
  --cluster $CLUSTER `
  --services $SERVICE `
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}" `
  --output table

# Logs de CloudWatch en tiempo real
aws logs tail $LOG_GROUP --follow

Pop-Location

# Scripts de validación completos
.\tests\aws\precheck\smoke_resources.ps1
.\tests\aws\precheck\validate_iam.ps1
.\tests\aws\smoke\smoke_cloudwatch.ps1
.\tests\aws\precheck\validate_budget.ps1
```

---

### Paso 3 — Re-deploy de imagen (forzar nueva task)

Ver `01.5_docker_push.md` — sección "Re-deploy".

---

### Cleanup

```powershell
# Recargar credenciales si la sesión cambió
Get-Content infra\env\.env.credentials | ForEach-Object {
  if ($_ -match "^\s*#" -or $_ -match "^\s*$") { return }
  $name, $value = $_ -split "=", 2
  [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), "Process")
}

Push-Location infra
# Tarda 3-7 min mientras ECS drena las tasks Fargate
terraform destroy
Pop-Location
```

---

## Linux / macOS (bash)

### Paso 0 — Cargar credenciales AWS

```bash
set -o allexport
source <(grep -v '^\s*#' infra/env/.env.credentials | grep -v '^\s*$')
set +o allexport

# Verificar
aws sts get-caller-identity
```

### Paso 1 — Desplegar la infraestructura

```bash
# Ir a infra/ guardando la ubicación actual
pushd infra

# Inicializar Terraform con el backend S3
terraform init

# Revisar el plan
terraform plan

# Aplicar
terraform apply

# Ver outputs
terraform output

# Volver al directorio anterior
popd
```

> Una vez completado, continuar con **`01.5_docker_push.md`** para subir la imagen.

---

### Paso 2 — Verificar el despliegue

```bash
pushd infra

CLUSTER=$(terraform output -raw cluster_name)
SERVICE=$(terraform output -raw service_name)
LOG_GROUP=$(terraform output -raw log_group_name)

# Estado del servicio
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}" \
  --output table

# Logs en tiempo real
aws logs tail "$LOG_GROUP" --follow

popd

# Scripts de validación (requiere bash + jq)
bash tests/aws/gitbash/precheck.sh
```

---

### Paso 3 — Re-deploy de imagen

Ver `01.5_docker_push.md` — sección "Re-deploy".

---

### Cleanup

```bash
set -o allexport
source <(grep -v '^\s*#' infra/env/.env.credentials | grep -v '^\s*$')
set +o allexport

pushd infra
terraform destroy   # tarda 3-7 min
popd
```

---

## Orden completo de ejecución

```
01_backend_bootstrap   →  terraform apply  (backend-bootstrap/)
02_infra_deploy        →  Paso 0: cargar credenciales
                       →  Paso 1: terraform apply  (infra/)     ← crea el repo ECR
01.5_docker_push       →  Paso 0: cargar credenciales
                       →  Paso 1: docker build + push a ECR
02_infra_deploy        →  Paso 2: verificar ECS service ACTIVE + task RUNNING
```

## Orden de cleanup

```
terraform destroy  (infra/)              ← primero
terraform destroy  (backend-bootstrap/)  ← después
```
