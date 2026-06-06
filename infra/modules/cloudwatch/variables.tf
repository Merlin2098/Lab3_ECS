variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como parte del nombre del log group."
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)."
}

variable "log_retention_days" {
  type        = number
  description = "Días de retención de logs en CloudWatch. 7 días recomendado para laboratorio."
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a todos los recursos del módulo."
  default     = {}
}
