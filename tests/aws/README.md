# tests/aws — Validación de infraestructura ECS Lab

Scripts de validación generados automáticamente (SPEC-009 §4). Leen los identificadores de recursos desde `terraform output` — no hay ARNs ni nombres hardcodeados.

## Prerrequisitos

- AWS CLI configurado con credenciales del laboratorio.
- `terraform` en PATH.
- PowerShell 7+ (Windows) o bash + jq (Linux/CI).
- `terraform apply` en `infra/` ya ejecutado.

## Tabla de validación

| Recurso        | Script                           | Valida                                        |
|----------------|----------------------------------|-----------------------------------------------|
| ECR            | `precheck/smoke_resources.ps1`   | Repositorio existe                            |
| ECS Cluster    | `precheck/smoke_resources.ps1`   | Cluster ACTIVE                                |
| ECS Service    | `precheck/smoke_resources.ps1`   | Service ACTIVE                                |
| CloudWatch     | `smoke/smoke_cloudwatch.ps1`     | Log group existe + retención configurada      |
| IAM            | `precheck/validate_iam.ps1`      | Ambos roles + trust policy + policies         |
| IAM (smoke)    | `smoke/smoke_iam.ps1`            | Roles asumibles por ecs-tasks.amazonaws.com   |
| Tags           | `precheck/validate_tags.ps1`     | 5 tags obligatorios en todos los recursos     |
| Budget         | `precheck/validate_budget.ps1`   | Al menos un budget configurado                |

## Uso rápido (PowerShell)

```powershell
# Desde la raíz del proyecto
.\tests\aws\precheck\smoke_resources.ps1
.\tests\aws\precheck\validate_iam.ps1
.\tests\aws\precheck\validate_tags.ps1
.\tests\aws\precheck\validate_budget.ps1
.\tests\aws\smoke\smoke_cloudwatch.ps1
.\tests\aws\smoke\smoke_iam.ps1
```

## Uso en CI/Linux (bash)

```bash
bash tests/aws/gitbash/precheck.sh
```

## Descargar logs de CloudWatch

```powershell
.\tests\aws\logs\download_cloudwatch_logs.ps1 -OutDir logs/ecs
```

## Exportar terraform outputs

```powershell
.\tests\aws\logs\export_pipeline_outputs.ps1
# Genera: logs/tf_outputs.json
```

> **Nota sobre tags:** Para que `validate_tags.ps1` encuentre los recursos, activa primero los Cost Allocation Tags en la consola AWS → Billing → Cost allocation tags → activar `Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter`.
