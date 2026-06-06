variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como nombre del cluster ECS."
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)."
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a todos los recursos del módulo."
  default     = {}
}
