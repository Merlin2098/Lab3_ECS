variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como prefijo del security group."
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)."
}

variable "container_port" {
  type        = number
  description = "Puerto del contenedor. Se usará para la regla de ingress del security group."
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a todos los recursos del módulo."
  default     = {}
}
