# ── Identificación del proyecto ─────────────────────────────────────────────

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

# ── Configuración de la aplicación ──────────────────────────────────────────

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
  description = "Tag de la imagen Docker en ECR. Usar tags semánticos en producción (ej. v1.0.0)."
  default     = "latest"
}

variable "log_retention_days" {
  type        = number
  description = "Días de retención de logs en CloudWatch. 7 días recomendado para laboratorio."
  default     = 7
}

# ── Gobernanza y tags (SPEC-009) ─────────────────────────────────────────────

variable "owner" {
  type        = string
  description = "Propietario del recurso. Requerido en los tags obligatorios (SPEC-009)."
  default     = "engineering"
}

variable "cost_center" {
  type        = string
  description = "Centro de costo para reportes de facturación (SPEC-009)."
  default     = "engineering"
}

variable "budget_limit_usd" {
  type        = number
  description = "Límite mensual del presupuesto AWS en USD."
  default     = 25
}

variable "budget_alert_email" {
  type        = string
  description = "Email para alertas de presupuesto. Dejar vacío para omitir la creación del SNS."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales a mergear con los tags comunes. No sobreescribe Project/Environment/Owner/ManagedBy/CostCenter."
  default     = {}
}
