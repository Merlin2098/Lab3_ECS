# SPEC-LAB-003B — Terraform Remote Backend con S3 State Lock
> **Versión:** 2.0 — Revisada post-auditoría técnica  
> **Cambios aplicados:** G-003B-01 al G-003B-07 (todos los hallazgos del technical review)

---

## Objetivo

Configurar Terraform Remote Backend usando Amazon S3 para almacenar el archivo de estado del laboratorio ECS, con locking nativo mediante S3 State Lock.

Este spec debe completarse **antes** de inicializar la infraestructura principal (`infra/`).

---

## Prerrequisitos

```bash
terraform version
# Se requiere: Terraform >= 1.10
```

> **Motivo:** `use_lockfile = true` para S3 State Lock fue introducido en **Terraform 1.10** (octubre 2024). Versiones anteriores producen el error: `An argument named "use_lockfile" is not expected here.`

---

## Restricciones obligatorias

- No usar DynamoDB para state locking.
- Usar S3 State Lock nativo (`use_lockfile = true`).
- Separar la creación del backend de la infraestructura principal.
- El directorio `backend-bootstrap/` **no comparte estado** con `infra/`.

---

## Conceptos clave antes de comenzar

### S3 State Lock vs. Provider Lock

Terraform usa dos mecanismos de locking distintos que suelen confundirse:

| Mecanismo | Archivo | Propósito |
|-----------|---------|-----------|
| **Provider Lock** | `.terraform.lock.hcl` (local) | Fija versiones de providers para reproducibilidad |
| **S3 State Lock** | `<key>.tflock` (en S3) | Previene modificaciones concurrentes del state file |

El **S3 State Lock** (habilitado con `use_lockfile = true`) crea un objeto llamado `<tu-key>.tflock` en el mismo bucket S3 cada vez que Terraform inicia una operación. El objeto se elimina al completar la operación. Si Terraform falla abruptamente y el lock queda "colgado", puede forzarse su liberación manualmente eliminando el objeto `.tflock` en S3.

---

## Estructura esperada

```text
project-root/
├── backend-bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── infra/
    ├── backend.tf
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

## Backend Bootstrap

El directorio `backend-bootstrap/` crea los recursos S3 que servirán como backend remoto para `infra/`. Este directorio **usa estado local** (no tiene su propio backend remoto).

> ⚠️ **Limitación conocida del laboratorio:** El estado de `backend-bootstrap/` se guarda localmente en `backend-bootstrap/terraform.tfstate`. Si este archivo se pierde, Terraform perderá el tracking del bucket S3 creado. En ese caso, el bucket debe gestionarse o eliminarse manualmente desde la consola AWS o CLI. En producción, el bootstrap state se gestiona con un backend independiente o se versiona en un repositorio.

### Recursos a crear

#### S3 Bucket para Terraform State

El bucket debe crearse con las siguientes configuraciones:

| Configuración | Valor | Motivo |
|---------------|-------|--------|
| Versioning | Habilitado | Permite recuperar versiones anteriores del state ante corrupción |
| Encryption | SSE-S3 (AES-256) | Cifrado en reposo sin overhead operativo de KMS |
| Block Public Access | Habilitado (todos los bloques) | El state file puede contener datos sensibles de infraestructura |
| `force_destroy` | `true` | Permite eliminar el bucket aunque contenga versiones del state file |

> ⚠️ **Por qué `force_destroy = true` es necesario en el bootstrap:**  
> Con versioning habilitado, S3 acumula versiones anteriores del `terraform.tfstate`. Al ejecutar `terraform destroy` en `backend-bootstrap/`, el bucket **no puede eliminarse** si contiene objetos con versiones, incluso si el bucket "parece" vacío. `force_destroy = true` permite que Terraform elimine todas las versiones automáticamente.  
> Esta configuración es específica del laboratorio. En producción, el bucket de state nunca se elimina.

#### Valor pedagógico del versioning

El versioning no es solo un requisito de seguridad; es una herramienta de recuperación:

- Si el `terraform.tfstate` se corrompe, puedes recuperar una versión anterior desde S3.
- Para hacerlo: Consola AWS → S3 → Bucket → objeto `terraform.tfstate` → "Show versions" → seleccionar versión anterior → "Restore".

---

## Archivo `infra/backend.tf`

Una vez creado el bucket, configura el backend remoto en `infra/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_BUCKET_NAME"
    key          = "ecs-lab/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

> **Nota sobre `encrypt = true`:** Este parámetro instruye a Terraform a verificar que la encryption esté habilitada en el bucket. Complementa (no reemplaza) la encryption SSE-S3 configurada en el bucket.

---

## Flujo operativo

### Paso 1 — Verificar versión de Terraform

```bash
terraform version
# Confirmar: Terraform v1.10.x o superior
```

### Paso 2 — Crear el backend

```bash
cd backend-bootstrap/
terraform init
terraform plan
terraform apply
```

### Paso 3 — Obtener outputs del backend

```bash
terraform output
# Anotar: bucket_name, region
```

### Paso 4 — Configurar el backend remoto

Editar `infra/backend.tf` reemplazando `REPLACE_WITH_BUCKET_NAME` con el valor del output.

### Paso 5 — Inicializar la infraestructura principal

```bash
cd ../infra/
terraform init
# Terraform detectará el backend S3 y solicitará confirmación de migración de state
terraform plan
terraform apply
```

> ⚠️ **Orden obligatorio:** El paso 2 debe completarse **antes** del paso 5. Si se ejecuta `terraform init` en `infra/` antes de que el bucket exista, Terraform fallará con un error de backend inaccesible.

---

## Cleanup del laboratorio

Para destruir todos los recursos al finalizar el lab:

```bash
# 1. Destruir infraestructura principal primero
cd infra/
terraform destroy

# 2. Destruir el backend (el bucket debe estar vacío de state files)
cd ../backend-bootstrap/
terraform destroy
# force_destroy = true permite eliminar el bucket con sus versiones internas
```

> **Nota:** `terraform destroy` en `infra/` elimina el state file del bucket S3, pero pueden quedar versiones anteriores del objeto. `force_destroy = true` en el bucket asegura que `terraform destroy` en `backend-bootstrap/` elimine también esas versiones.

---

## Outputs requeridos de `backend-bootstrap/`

| Output | Descripción |
|--------|-------------|
| `bucket_name` | Nombre del bucket S3 creado |
| `bucket_arn` | ARN del bucket |
| `region` | Región donde se creó el bucket |

---

## Criterios de aceptación

- [ ] Existe directorio `backend-bootstrap/` separado de `infra/`.
- [ ] El bucket S3 se crea con versioning habilitado.
- [ ] El bucket S3 se crea con encryption SSE-S3 (AES-256).
- [ ] El bucket S3 tiene block public access habilitado en todos los bloques.
- [ ] El bucket S3 tiene `force_destroy = true`.
- [ ] `infra/backend.tf` usa backend `s3`.
- [ ] `infra/backend.tf` incluye `use_lockfile = true`.
- [ ] `infra/backend.tf` incluye `encrypt = true`.
- [ ] No existe recurso DynamoDB en ningún directorio.
- [ ] No existe atributo `dynamodb_table` en ningún archivo.
- [ ] `terraform init` en `infra/` conecta correctamente con el backend S3.
- [ ] El state file aparece en S3 tras ejecutar `terraform apply` en `infra/`.
- [ ] `terraform destroy` en `backend-bootstrap/` completa sin error de "bucket not empty".

---

## Referencias

- [Terraform — S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform — S3 State Locking nativo (1.10+)](https://developer.hashicorp.com/terraform/language/backend/s3#state-locking)
- [Terraform — required_version](https://developer.hashicorp.com/terraform/language/terraform#terraform-required_version)
- [Terraform — Backend Configuration](https://developer.hashicorp.com/terraform/language/backend)
- [AWS S3 — Best Practices para buckets de Terraform state](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [AWS S3 — Recuperación de objetos con versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/RestoringPreviousVersions.html)
