# Lab3 ECS — Amazon ECS + ECR + Fargate con Terraform

Laboratorio de despliegue de una aplicación FastAPI contenerizada en AWS usando ECS Fargate, ECR, CloudWatch y Terraform modular con backend remoto S3.

## Prerrequisitos

- Terraform >= 1.10 (`terraform version`)
- AWS CLI configurado (`aws sts get-caller-identity`)
- Docker instalado
- Python 3.11+ (solo para desarrollo local de la app)

## Estructura del proyecto

```
app/                    FastAPI app + Dockerfile
backend-bootstrap/      Crea el bucket S3 de Terraform state
infra/                  Infraestructura principal (módulos ECS/ECR/IAM/CloudWatch/Networking)
  └── modules/
      ├── ecr/
      ├── ecs_cluster/
      ├── ecs_task_definition/
      ├── ecs_service/
      ├── cloudwatch/
      ├── iam/
      └── networking/
tests/aws/              Scripts de validación post-deploy (SPEC-009)
```

## Orden de ejecución

### 1. Crear el backend S3

```bash
cd backend-bootstrap/
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars si es necesario
terraform init
terraform plan
terraform apply
terraform output bucket_name
```

### 2. Configurar el backend remoto en infra/

Editar [infra/backend.tf](infra/backend.tf) y reemplazar `REPLACE_WITH_BUCKET_NAME` con el valor del output anterior.

### 3. Construir y subir la imagen Docker a ECR

```bash
# Obtener la URL del repositorio (después del apply o antes con plan)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
REPO_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/ecs-terraform-lab-dev"

# Login en ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Build y push
docker build -t ecs-terraform-lab app/
docker tag ecs-terraform-lab:latest "${REPO_URL}:latest"
docker push "${REPO_URL}:latest"
```

> **Nota:** El repositorio ECR debe existir antes del push. Se crea en el paso 4.

### 4. Desplegar la infraestructura principal

```bash
cd infra/
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars: añadir budget_alert_email si se quieren alertas
terraform init
terraform plan
terraform apply
```

Tiempo estimado de apply: 2-4 minutos. ECS tarda en arrancar la task Fargate.

### 5. Verificar el despliegue

```bash
# Ver outputs
terraform output

# Estado del servicio ECS
aws ecs describe-services \
  --cluster $(terraform output -raw cluster_name) \
  --services $(terraform output -raw service_name)

# Ejecutar scripts de validación (PowerShell)
cd ..
.\tests\aws\precheck\smoke_resources.ps1
.\tests\aws\precheck\validate_iam.ps1
.\tests\aws\smoke\smoke_cloudwatch.ps1

# O en bash/CI
bash tests/aws/gitbash/precheck.sh
```

### 6. Re-deploy de imagen (forzar nueva task)

```bash
aws ecs update-service \
  --cluster $(terraform -chdir=infra output -raw cluster_name) \
  --service $(terraform -chdir=infra output -raw service_name) \
  --force-new-deployment
```

## Cleanup

```bash
# 1. Destruir infraestructura principal (tarda 3-7 min drenando Fargate)
cd infra/
terraform destroy

# 2. Destruir el backend S3
cd ../backend-bootstrap/
terraform destroy
# force_destroy=true elimina el bucket con todas las versiones del state
```

## Notas de producción

> Las siguientes simplificaciones son aceptables para este laboratorio pero **no deben replicarse en producción**:

| Configuración | Laboratorio | Producción |
|---|---|---|
| `force_delete = true` (ECR) | Facilita destroy | Protege imágenes de borrado accidental |
| `assign_public_ip = true` | Subnets públicas de VPC default | Subnets privadas + NAT Gateway o VPC Endpoints |
| `image_tag = "latest"` | Simplicidad | Tags semánticos (v1.0.0) o digests de imagen |
| Egress irrestricto (SG) | Simplicidad | Solo TCP 443 a endpoints necesarios |
| IAM wildcards en operador | Simplicidad educativa | ARN específicos + condiciones de contexto |

## Permisos del operador Terraform

Ver [specs/SPEC-LAB-003C.md](specs/SPEC-LAB-003C.md) para la lista completa de permisos IAM necesarios (`TerraformLabInfraPolicy` + `TerraformLabBackendPolicy` + `iam:PassRole`).
