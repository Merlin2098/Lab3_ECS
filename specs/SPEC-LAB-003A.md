# SPEC-LAB-003A — Infraestructura modular ECS + ECR + Fargate
> **Versión:** 2.0 — Revisada post-auditoría técnica  
> **Cambios aplicados:** G-003A-01 al G-003A-08 (todos los hallazgos del technical review)

---

## Objetivo

Implementar un laboratorio de despliegue de una aplicación contenerizada en AWS usando:

- Amazon ECR
- Amazon ECS con AWS Fargate
- CloudWatch Logs
- Terraform con arquitectura modular

La infraestructura debe estar separada por módulos. No se permite crear todos los recursos directamente en `infra/main.tf`.

---

## Prerrequisitos

Antes de comenzar, verificar:

```bash
terraform version
# Se requiere: Terraform >= 1.10
# Se requiere: AWS Provider ~> 5.0
```

> **Nota:** Este laboratorio usa `use_lockfile = true` para S3 State Lock, disponible únicamente en Terraform 1.10 o superior. Versiones anteriores producirán un error de inicialización.

---

## Restricciones obligatorias

- Usar Terraform con `required_version >= "1.10"`.
- Separar recursos por módulos. No crear infraestructura monolítica.
- No hardcodear nombres críticos; usar variables.
- Incluir `force_delete = true` en Amazon ECR para facilitar destrucción del laboratorio.

  > ⚠️ **Simplificación de laboratorio:** `force_delete = true` permite eliminar un repositorio ECR aunque contenga imágenes. Esta configuración **no debe usarse en producción**.

- Mantener el laboratorio simple: sin ALB, sin Auto Scaling, sin Route53, sin GitHub Actions.
- Tipar todas las variables (`type`) e incluir `description` en todos los outputs.
- El módulo `iam` es obligatorio y debe crearse dentro de `infra/modules/iam/`.

---

## Estructura esperada

```text
project-root/
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── backend-bootstrap/          # Ver SPEC-LAB-003B
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── infra/
    ├── backend.tf
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars.example
    ├── env/                    # Credenciales AWS locales — nunca commitear
    │   ├── .env.example        # Plantilla con placeholders (commiteado)
    │   └── .env.credentials    # Credenciales reales (ignorado por git)
    └── modules/
        ├── ecr/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── ecs_cluster/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── ecs_task_definition/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── ecs_service/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── cloudwatch/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        ├── iam/                # Requerido — ver SPEC-LAB-003C
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        └── networking/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

> **`infra/env/`** — Directorio de credenciales AWS para ejecución local.
>
> | Archivo | Commiteado | Propósito |
> |---------|-----------|-----------|
> | `.env.example` | ✅ Sí | Plantilla con placeholders. Base para crear el archivo real. |
> | `.env.credentials` | ❌ No | Credenciales reales. Debe estar en `.gitignore`. **Nunca commitear.** |
>
> Copiar `.env.example` a `.env.credentials` y reemplazar los valores antes de ejecutar cualquier comando AWS o Terraform.

---

## Dependencias entre módulos

El orden de dependencia en `infra/main.tf` debe respetarse. Terraform resuelve las dependencias implícitas a través de referencias entre outputs e inputs; no se requiere `depends_on` explícito si las referencias están correctamente configuradas.

```
cloudwatch  ──┐
ecr         ──┼──► ecs_task_definition ──┐
iam         ──┘                          ├──► ecs_service
                                          │
ecs_cluster ─────────────────────────────┤
networking  ─────────────────────────────┘
```

**Descripción de cada dependencia:**

| Módulo consumidor | Módulo proveedor | Dato consumido |
|-------------------|-----------------|----------------|
| `ecs_task_definition` | `cloudwatch` | `log_group_name` |
| `ecs_task_definition` | `ecr` | `repository_url` |
| `ecs_task_definition` | `iam` | `task_execution_role_arn`, `task_role_arn` |
| `ecs_service` | `ecs_cluster` | `cluster_id` |
| `ecs_service` | `ecs_task_definition` | `task_definition_arn` |
| `ecs_service` | `networking` | `subnet_ids`, `security_group_id` |

---

## Módulo `ecr`

Crea el repositorio Amazon ECR donde se almacenará la imagen Docker de la aplicación.

### Recursos a crear

- `aws_ecr_repository`

### Configuración obligatoria

```hcl
force_delete = true
```

> ⚠️ **Simplificación de laboratorio:** permite destruir el repositorio aunque tenga imágenes. No usar en producción.

### Variables requeridas

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | `string` | Nombre base del proyecto |
| `environment` | `string` | Ambiente (`dev`, `staging`, `prod`) |

### Outputs requeridos

| Output | Descripción |
|--------|-------------|
| `repository_url` | URL completa del repositorio ECR |
| `repository_arn` | ARN del repositorio |
| `repository_name` | Nombre del repositorio |

---

## Módulo `ecs_cluster`

Crea el ECS Cluster que agrupará los servicios y tasks Fargate.

### Recursos a crear

- `aws_ecs_cluster`

### Variables requeridas

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | `string` | Nombre base del proyecto |
| `environment` | `string` | Ambiente |

### Outputs requeridos

| Output | Descripción |
|--------|-------------|
| `cluster_id` | ID del cluster ECS |
| `cluster_arn` | ARN del cluster |
| `cluster_name` | Nombre del cluster |

---

## Módulo `ecs_task_definition`

Crea la Task Definition de ECS con configuración Fargate. Es el módulo de mayor complejidad de integración porque consume outputs de `cloudwatch`, `ecr` e `iam`.

### Recursos a crear

- `aws_ecs_task_definition`

### Parámetros obligatorios de Fargate

```hcl
requires_compatibilities = ["FARGATE"]
network_mode             = "awsvpc"
```

> **Nota técnica:** Fargate solo soporta `network_mode = "awsvpc"`. Cualquier otro valor causará error en `terraform apply`.

### Container definition — Campos mínimos requeridos

El container definition se pasa como JSON. Los campos mínimos obligatorios son:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | `string` | Nombre del contenedor (se recomienda usar `project_name`) |
| `image` | `string` | URL completa de la imagen: `<repository_url>:<image_tag>` |
| `portMappings` | `list` | Puerto del contenedor y protocolo |
| `logConfiguration` | `object` | Configuración de CloudWatch Logs |

**Estructura mínima del `logConfiguration`:**

```json
{
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "<log_group_name>",
    "awslogs-region": "<aws_region>",
    "awslogs-stream-prefix": "ecs"
  }
}
```

> El `log_group_name` debe recibirse como variable desde el output del módulo `cloudwatch`.

### Variables requeridas

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | `string` | Nombre base del proyecto |
| `environment` | `string` | Ambiente |
| `aws_region` | `string` | Región AWS |
| `task_cpu` | `number` | CPU en unidades (ej. `256`) |
| `task_memory` | `number` | Memoria en MB (ej. `512`) |
| `container_port` | `number` | Puerto expuesto por el contenedor |
| `image_tag` | `string` | Tag de la imagen Docker |
| `repository_url` | `string` | URL del repositorio ECR (output de módulo `ecr`) |
| `log_group_name` | `string` | Nombre del Log Group (output de módulo `cloudwatch`) |
| `execution_role_arn` | `string` | ARN del Task Execution Role (output de módulo `iam`) |
| `task_role_arn` | `string` | ARN del Task Role (output de módulo `iam`) |

### Outputs requeridos

| Output | Descripción |
|--------|-------------|
| `task_definition_arn` | ARN completo de la Task Definition |
| `task_definition_family` | Family name de la Task Definition |

---

## Módulo `ecs_service`

Crea el ECS Service que mantiene las tasks Fargate en ejecución.

### Recursos a crear

- `aws_ecs_service`

### Configuración obligatoria

```hcl
launch_type    = "FARGATE"
desired_count  = var.desired_count
```

### Variables requeridas

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | `string` | Nombre base del proyecto |
| `environment` | `string` | Ambiente |
| `cluster_id` | `string` | ID del cluster ECS (output de módulo `ecs_cluster`) |
| `task_definition_arn` | `string` | ARN de la Task Definition (output de módulo `ecs_task_definition`) |
| `desired_count` | `number` | Número de tasks deseadas |
| `subnet_ids` | `list(string)` | Lista de subnet IDs (output de módulo `networking`) |
| `security_group_id` | `string` | ID del security group (output de módulo `networking`) |

### Outputs requeridos

| Output | Descripción |
|--------|-------------|
| `service_name` | Nombre del servicio ECS |
| `service_id` | ID del servicio ECS |

---

## Módulo `cloudwatch`

Crea el Log Group de CloudWatch donde ECS escribirá los logs de los contenedores.

### Recursos a crear

- `aws_cloudwatch_log_group`

### Configuración obligatoria

El Log Group **debe** tener retención configurada para evitar costos no controlados.

```hcl
retention_in_days = var.log_retention_days  # Default recomendado: 7
```

> **Buena práctica AWS:** Sin `retention_in_days`, los logs se retienen indefinidamente y generan costos acumulativos. Para laboratorios se recomiendan 7 días.

### Variables requeridas

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `project_name` | `string` | — | Nombre base del proyecto |
| `environment` | `string` | — | Ambiente |
| `log_retention_days` | `number` | `7` | Días de retención de logs |

### Outputs requeridos

| Output | Descripción |
|--------|-------------|
| `log_group_name` | Nombre del Log Group (usado por `ecs_task_definition`) |
| `log_group_arn` | ARN del Log Group |

---

## Módulo `networking`

Resuelve los recursos de red necesarios para que las tasks Fargate puedan ejecutarse: subnets y security group.

### Estrategia del laboratorio

Para simplificar, el módulo **reutiliza la VPC default** de la cuenta AWS y sus subnets existentes. No se crea VPC nueva.

> ⚠️ **Nota de seguridad:** La VPC default contiene subnets públicas. Las tasks Fargate desplegadas en subnets públicas con `assign_public_ip = true` son accesibles desde internet. Esta configuración es aceptable para un laboratorio sin datos sensibles, pero **no debe replicarse en producción**. En producción se usan subnets privadas con NAT Gateway o VPC Endpoints para ECR y CloudWatch.

### Recursos a crear

- `aws_security_group` — Security group para las tasks Fargate
- `aws_security_group_rule` — Reglas de entrada y salida

### Reglas de security group requeridas

| Dirección | Protocolo | Puerto | Destino | Motivo |
|-----------|-----------|--------|---------|--------|
| Egress | TCP | 443 | 0.0.0.0/0 | Descarga de imágenes desde ECR (HTTPS) |
| Egress | TCP | 443 | 0.0.0.0/0 | Escritura de logs en CloudWatch (HTTPS) |
| Ingress | TCP | `container_port` | 0.0.0.0/0 | Acceso al puerto de la aplicación |

> **Simplificación permitida:** Se puede usar una única regla de egress `all traffic → 0.0.0.0/0` para el laboratorio. Documentar que en producción se restringe.

### Variables requeridas

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | `string` | Nombre base del proyecto |
| `environment` | `string` | Ambiente |
| `container_port` | `number` | Puerto del contenedor para regla de ingress |

### Outputs requeridos

| Output | Descripción |
|--------|-------------|
| `subnet_ids` | Lista de subnet IDs de la VPC default |
| `security_group_id` | ID del security group creado |
| `vpc_id` | ID de la VPC utilizada |

---

## Módulo `iam`

Ver **SPEC-LAB-003C** para la especificación completa de roles y políticas IAM.

Resumen de lo que debe crear este módulo:

- `aws_iam_role` — Task Execution Role
- `aws_iam_role` — Task Role (obligatorio en este lab con fines didácticos)
- Attachments de policies correspondientes

### Outputs mínimos requeridos por este módulo

| Output | Descripción |
|--------|-------------|
| `task_execution_role_arn` | ARN del Task Execution Role |
| `task_execution_role_name` | Nombre del Task Execution Role |
| `task_role_arn` | ARN del Task Role |
| `task_role_name` | Nombre del Task Role |

---

## Variables mínimas del proyecto (`infra/variables.tf`)

```hcl
variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como prefijo en todos los recursos."
  default     = "ecs-terraform-lab"
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)."
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "Región AWS donde se despliega el laboratorio."
  default     = "us-east-1"
}

variable "container_port" {
  type        = number
  description = "Puerto expuesto por el contenedor de la aplicación."
  default     = 8000
}

variable "task_cpu" {
  type        = number
  description = "CPU asignada a la Task Definition en unidades ECS (256 = 0.25 vCPU)."
  default     = 256
}

variable "task_memory" {
  type        = number
  description = "Memoria asignada a la Task Definition en MB."
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Número de tasks Fargate que el servicio ECS debe mantener en ejecución."
  default     = 1
}

variable "image_tag" {
  type        = string
  description = "Tag de la imagen Docker en ECR."
  default     = "latest"
}

variable "log_retention_days" {
  type        = number
  description = "Días de retención de logs en CloudWatch. Default: 7 días para laboratorio."
  default     = 7
}
```

> ⚠️ **Nota sobre `image_tag = "latest"`:** Usar `latest` es una simplificación de laboratorio. En producción, ECS puede no detectar cambios de imagen si el digest cambia pero el tag permanece igual. Se recomienda usar tags semánticos (`v1.0.0`) o digests de imagen para deployments confiables. Si necesitas forzar un re-deploy durante el lab: `aws ecs update-service --cluster <name> --service <name> --force-new-deployment`.

---

## Comportamiento esperado de `terraform destroy`

> ⚠️ **Tiempo de espera:** `terraform destroy` con Fargate puede tardar **3 a 7 minutos** mientras ECS drena las tasks en ejecución antes de eliminarlas. Esto es comportamiento normal, no un error. No interrumpir el proceso.

El orden de destrucción será aproximadamente el inverso al de creación:
1. ECS Service (drena y detiene tasks)
2. ECS Task Definition
3. ECS Cluster
4. CloudWatch Log Group
5. ECR Repository (forzado por `force_delete = true`)
6. IAM Roles y Policies
7. Security Group

---

## Criterios de aceptación

- [ ] `terraform init` funciona correctamente con el backend remoto configurado.
- [ ] `terraform plan` no produce errores.
- [ ] `terraform apply` crea todos los recursos sin errores.
- [ ] Los recursos están separados por módulos (prohibido recurso directo en `infra/main.tf`).
- [ ] Todos los módulos tienen `main.tf`, `variables.tf` y `outputs.tf`.
- [ ] Todas las variables tienen `type` y `description`.
- [ ] Todos los outputs tienen `description`.
- [ ] ECR usa `force_delete = true`.
- [ ] ECS usa Fargate (`launch_type = "FARGATE"`).
- [ ] La Task Definition usa `requires_compatibilities = ["FARGATE"]` y `network_mode = "awsvpc"`.
- [ ] La Task Definition referencia correctamente `execution_role_arn` y `task_role_arn`.
- [ ] La Task Definition envía logs a CloudWatch (`logConfiguration` configurado).
- [ ] El CloudWatch Log Group tiene `retention_in_days` configurado.
- [ ] El módulo `networking` expone `subnet_ids` y `security_group_id`.
- [ ] El módulo `iam` está en `infra/modules/iam/` y expone los ARNs de los roles.
- [ ] El servicio ECS queda en estado `ACTIVE` con la task en estado `RUNNING`.
- [ ] `terraform destroy` completa sin errores (puede tardar varios minutos).

---

## Referencias

- [Amazon ECS — Task Definition Parameters](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [Amazon ECS — Fargate Task Networking](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html)
- [Amazon CloudWatch Logs — Using awslogs driver](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_awslogs.html)
- [Terraform — Module Structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Terraform — Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Terraform AWS Provider — aws_ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)
- [Terraform AWS Provider — aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)
