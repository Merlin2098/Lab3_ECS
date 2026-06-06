# 02 — Levantar la infraestructura ECS

Despliega ECR, ECS Cluster, ECS Service, IAM, CloudWatch y Networking.
Ejecutar **después** de completar `01_backend_bootstrap.md`.

> **Workflow completo:**
> `01_backend_bootstrap` → `02_infra_deploy` (Paso 1: terraform apply) → `01.5_docker_push` → `02_infra_deploy` (Paso 2: verificar)

---

## Windows (PowerShell)

### Paso 1 — Desplegar la infraestructura

```powershell
# 1. Ir a infra/ guardando la ubicación actual
Push-Location infra

# 2. Inicializar Terraform con el backend S3
terraform init

# 3. Revisar el plan completo
terraform plan

# 4. Aplicar (tarda ~2-4 min; crea el repositorio ECR entre otros recursos)
terraform apply

# 5. Ver los outputs del despliegue
terraform output

# 6. Volver al directorio anterior
Pop-Location
```

> Una vez completado este paso, el repositorio ECR ya existe.
> Continuar con **`01.5_docker_push.md`** para subir la imagen, luego volver al Paso 2.

---

### Paso 2 — Verificar el despliegue

```powershell
Push-Location infra

# Estado del servicio ECS
$CLUSTER   = terraform output -raw cluster_name
$SERVICE   = terraform output -raw service_name
$LOG_GROUP = terraform output -raw log_group_name

aws ecs describe-services `
  --cluster $CLUSTER `
  --services $SERVICE `
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}" `
  --output table

# Logs de CloudWatch (últimas entradas)
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
Push-Location infra
# Tarda 3-7 min mientras ECS drena las tasks Fargate
terraform destroy
Pop-Location
```

---

## Linux / macOS (bash)

### Paso 1 — Desplegar la infraestructura

```bash
# 1. Ir a infra/ guardando la ubicación actual
pushd infra

# 2. Inicializar Terraform con el backend S3
terraform init

# 3. Revisar el plan
terraform plan

# 4. Aplicar
terraform apply

# 5. Ver outputs
terraform output

# 6. Volver al directorio anterior
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
pushd infra
terraform destroy   # tarda 3-7 min
popd
```

---

## Orden completo de ejecución

```
01_backend_bootstrap   →  terraform apply  (backend-bootstrap/)
02_infra_deploy        →  terraform apply  (infra/)              ← crea el repo ECR
01.5_docker_push       →  docker build + push a ECR
02_infra_deploy        →  verificar ECS service ACTIVE + task RUNNING
```

## Orden de cleanup

```
terraform destroy  (infra/)              ← primero
terraform destroy  (backend-bootstrap/)  ← después
```
