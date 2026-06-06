# SPEC-LAB-003C — IAM Roles y Policies para laboratorio ECS
> **Versión:** 2.0 — Revisada post-auditoría técnica  
> **Cambios aplicados:** G-003C-01 al G-003C-07 (todos los hallazgos del technical review)

---

## Objetivo

Crear los roles y políticas IAM necesarios para ejecutar el laboratorio ECS + ECR + Fargate con Terraform, siguiendo el principio de mínimo privilegio en la medida que es razonable para un contexto educativo.

---

## Prerrequisitos

Conocer la diferencia entre los dos roles IAM de ECS antes de implementar:

```
┌─────────────────────────────────────────────────────────────────┐
│                        ECS FARGATE                              │
│                                                                 │
│  Agente ECS (plano de control)                                  │
│  ┌──────────────────────────────┐                               │
│  │ Task Execution Role          │◄── Usado por ECS para:        │
│  │ ecs-...-task-execution-role  │    - Descargar imagen de ECR  │
│  └──────────────────────────────┘    - Escribir logs en CW      │
│                                                                 │
│  Contenedor (tu aplicación)                                     │
│  ┌──────────────────────────────┐                               │
│  │ Task Role                    │◄── Usado por tu app para:     │
│  │ ecs-...-task-role            │    - Llamar servicios AWS      │
│  └──────────────────────────────┘    (S3, DynamoDB, etc.)       │
└─────────────────────────────────────────────────────────────────┘
```

> **Regla mnemotécnica:** El **Execution Role** lo usa ECS para *arrancar* el contenedor. El **Task Role** lo usa *el contenedor* una vez que está corriendo.

---

## Módulo IAM

Crear el módulo en:

```
infra/modules/iam/
├── main.tf
├── variables.tf
└── outputs.tf
```

### Recursos a crear

- `aws_iam_role` — Task Execution Role (obligatorio)
- `aws_iam_role` — Task Role (obligatorio en este lab con fines didácticos)
- `aws_iam_role_policy_attachment` — Attachment de la managed policy al Execution Role

> **Por qué crear el Task Role si está vacío:** Este laboratorio crea el Task Role sin permisos para demostrar la separación de responsabilidades entre ambos roles. En producción, el Task Role recibiría los permisos específicos que necesita la aplicación (por ejemplo, `s3:GetObject` para leer archivos, `dynamodb:Query` para consultar tablas). Entender esta separación desde el principio es fundamental para implementar ECS de forma segura.

---

## ECS Task Execution Role

**Nombre sugerido:** `ecs-terraform-lab-task-execution-role`

### Trust Policy

Permite que el servicio ECS Tasks asuma este rol:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Policy recomendada: Managed Policy de AWS

Se recomienda usar la managed policy oficial de AWS en lugar de una policy inline:

```
arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

Esta managed policy incluye exactamente los permisos mínimos necesarios para Fargate:

| Acción | Recurso | Propósito |
|--------|---------|-----------|
| `ecr:GetAuthorizationToken` | `*` | Autenticarse en ECR (**ver nota crítica abajo**) |
| `ecr:BatchCheckLayerAvailability` | `*` | Verificar capas de imagen |
| `ecr:GetDownloadUrlForLayer` | `*` | Descargar capas de imagen |
| `ecr:BatchGetImage` | `*` | Obtener la imagen completa |
| `logs:CreateLogStream` | `*` | Crear stream en el Log Group |
| `logs:PutLogEvents` | `*` | Escribir eventos de log |
| `logs:CreateLogGroup` | `*` | Crear el Log Group si no existe |

> **⚠️ Nota crítica sobre `ecr:GetAuthorizationToken` y `Resource: "*"`**
>
> Esta acción **no acepta ARN de recurso específico**. Es una restricción de diseño del servicio ECR: la autenticación es una operación global que devuelve un token válido para todos los repositorios ECR de la región, independientemente del repositorio específico al que se quiera acceder. Intentar restringir el recurso a un ARN de repositorio concreto producirá un error de validación de IAM.
>
> Esto es una excepción documentada por AWS al principio de mínimo privilegio por recursos. Las acciones de autenticación de nivel de servicio (`GetAuthorizationToken`, `GetSessionToken`, etc.) operan siempre sobre `Resource: "*"` por diseño.
>
> Referencia: [AWS IAM — Actions for Amazon ECR](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerregistry.html)

> **⚠️ Por qué `logs:CreateLogGroup` es necesario:**  
> El Execution Role necesita `logs:CreateLogGroup` para el caso en que el Log Group no exista al momento en que ECS intenta escribir logs. Aunque el módulo `cloudwatch` de este lab crea el Log Group explícitamente (eliminando la necesidad práctica de este permiso), la managed policy lo incluye como salvaguarda. Omitirlo en una policy inline personalizada puede causar fallos silenciosos de logging difíciles de diagnosticar.

---

## ECS Task Role

**Nombre sugerido:** `ecs-terraform-lab-task-role`

### Trust Policy

Idéntica al Execution Role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Permisos

Para este laboratorio básico, el Task Role **no necesita permisos adicionales**. La aplicación de ejemplo no llama a servicios AWS desde dentro del contenedor.

Crear el rol sin policies adicionales adjuntas. En producción, este rol recibiría permisos específicos de la aplicación (ejemplo: `s3:GetObject` sobre un bucket específico, no sobre `*`).

---

## Permisos para el operador Terraform

El usuario o rol que ejecuta Terraform necesita permisos para gestionar todos los recursos del laboratorio. A continuación se documentan los permisos mínimos recomendados, organizados por servicio.

> ⚠️ **Advertencia importante — No replicar en producción:**  
> Los permisos documentados a continuación usan wildcards de acción por simplicidad educativa. En producción, cada permiso debe restringirse por ARN de recurso y, donde sea posible, por condiciones de contexto (región, account ID, tags). El objetivo en producción es que el operador de Terraform solo pueda gestionar recursos del proyecto, no todos los recursos de la cuenta.

### Policy 1: `TerraformLabInfraPolicy`

Permisos para gestionar la infraestructura del laboratorio:

**ECR:**
```
ecr:CreateRepository
ecr:DeleteRepository
ecr:DescribeRepositories
ecr:ListTagsForResource
ecr:TagResource
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
ecr:BatchGetImage
ecr:GetDownloadUrlForLayer
```

**ECS:**
```
ecs:CreateCluster
ecs:DeleteCluster
ecs:DescribeClusters
ecs:RegisterTaskDefinition
ecs:DeregisterTaskDefinition
ecs:DescribeTaskDefinition
ecs:CreateService
ecs:UpdateService
ecs:DeleteService
ecs:DescribeServices
ecs:ListServices
ecs:ListTagsForResource
ecs:TagResource
```

**CloudWatch Logs:**
```
logs:CreateLogGroup
logs:DeleteLogGroup
logs:DescribeLogGroups
logs:PutRetentionPolicy
logs:ListTagsForResource
logs:TagResource
```

**EC2 (networking):**
```
ec2:DescribeVpcs
ec2:DescribeSubnets
ec2:DescribeSecurityGroups
ec2:CreateSecurityGroup
ec2:DeleteSecurityGroup
ec2:AuthorizeSecurityGroupIngress
ec2:AuthorizeSecurityGroupEgress
ec2:RevokeSecurityGroupIngress
ec2:RevokeSecurityGroupEgress
ec2:CreateTags
ec2:DescribeTags
```

**IAM:**
```
iam:CreateRole
iam:DeleteRole
iam:GetRole
iam:PassRole
iam:AttachRolePolicy
iam:DetachRolePolicy
iam:ListRolePolicies
iam:ListAttachedRolePolicies
iam:GetPolicy
iam:TagRole
iam:UntagRole
```

### Policy 2: `TerraformLabBackendPolicy`

Permisos para gestionar el backend S3:

```
s3:CreateBucket
s3:DeleteBucket
s3:GetBucketVersioning
s3:PutBucketVersioning
s3:GetEncryptionConfiguration
s3:PutEncryptionConfiguration
s3:GetBucketPublicAccessBlock
s3:PutBucketPublicAccessBlock
s3:GetBucketTagging
s3:PutBucketTagging
s3:GetObject
s3:PutObject
s3:DeleteObject
s3:DeleteObjectVersion
s3:ListBucket
s3:ListBucketVersions
s3:GetBucketLocation
```

---

## Permiso crítico: `iam:PassRole`

Terraform necesita `iam:PassRole` para asignar los roles IAM a la Task Definition de ECS. Sin este permiso, `terraform apply` fallará con un error de autorización al intentar crear la Task Definition.

La restricción de recurso con ARN pattern limita qué roles puede pasar Terraform:

```json
{
  "Effect": "Allow",
  "Action": "iam:PassRole",
  "Resource": [
    "arn:aws:iam::ACCOUNT_ID:role/ecs-terraform-lab-*"
  ]
}
```

Reemplazar `ACCOUNT_ID` con el ID de cuenta AWS del laboratorio.

> **Buena práctica:** El wildcard `*` al final del ARN limita `PassRole` únicamente a roles con el prefijo `ecs-terraform-lab-`. Esto sigue el principio de mínimo privilegio para esta acción: Terraform solo puede asignar roles del proyecto, no cualquier rol de la cuenta (incluyendo roles de administrador).

---

## Permisos para ECR Push desde entorno local

El usuario que construye y sube la imagen Docker necesita estos permisos adicionales:

```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:PutImage"
  ],
  "Resource": "*"
}
```

> **Nota sobre `Resource: "*"` en el push:** `ecr:GetAuthorizationToken` requiere `Resource: "*"` por las mismas razones explicadas en la sección del Execution Role. Las acciones de upload (`InitiateLayerUpload`, `UploadLayerPart`, etc.) pueden restringirse al ARN del repositorio específico en producción.

---

## Integración con el módulo `ecs_task_definition`

La Task Definition debe referenciar ambos roles:

```hcl
execution_role_arn = module.iam.task_execution_role_arn
task_role_arn      = module.iam.task_role_arn
```

Si por algún motivo se decide no usar Task Role, debe documentarse explícitamente en el código con un comentario que explique el motivo (ej. `# task_role_arn omitido: la aplicación no requiere acceso a servicios AWS`).

---

## Outputs requeridos del módulo `iam`

```hcl
output "task_execution_role_arn" {
  description = "ARN del ECS Task Execution Role. Requerido por la Task Definition."
}

output "task_execution_role_name" {
  description = "Nombre del ECS Task Execution Role."
}

output "task_role_arn" {
  description = "ARN del ECS Task Role. Requerido por la Task Definition."
}

output "task_role_name" {
  description = "Nombre del ECS Task Role."
}
```

---

## Criterios de aceptación

- [ ] Existe módulo IAM en `infra/modules/iam/` con `main.tf`, `variables.tf` y `outputs.tf`.
- [ ] ECS Task Execution Role existe con trust policy hacia `ecs-tasks.amazonaws.com`.
- [ ] ECS Task Role existe con trust policy hacia `ecs-tasks.amazonaws.com`.
- [ ] `AmazonECSTaskExecutionRolePolicy` está adjunta al Execution Role (o policy equivalente con `logs:CreateLogGroup` incluido).
- [ ] La Task Definition usa `execution_role_arn` del módulo `iam`.
- [ ] La Task Definition usa `task_role_arn` del módulo `iam`.
- [ ] Terraform puede ejecutar `iam:PassRole` para los roles del lab.
- [ ] ECS puede descargar la imagen desde ECR sin errores de permisos.
- [ ] ECS puede escribir logs en CloudWatch sin errores de permisos.
- [ ] La aplicación corre en ECS Fargate sin errores de permisos en los logs.
- [ ] Los permisos del operador Terraform están documentados con el disclaimer de producción.

---

## Referencias

- [Amazon ECS — Task Execution IAM Role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)
- [Amazon ECS — Task IAM Role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
- [AWS Managed Policy — AmazonECSTaskExecutionRolePolicy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonECSTaskExecutionRolePolicy.html)
- [AWS IAM — Actions for Amazon ECR](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerregistry.html)
- [AWS IAM — Actions for Amazon ECS](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonelasticcontainerservice.html)
- [AWS IAM — Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS IAM — PassRole explained](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_passrole.html)
- [Terraform AWS Provider — aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)
- [Terraform AWS Provider — aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)
