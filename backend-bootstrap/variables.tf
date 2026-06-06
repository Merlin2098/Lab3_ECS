variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como prefijo del bucket de state."
  default     = "ecs-terraform-lab"
}

variable "aws_region" {
  type        = string
  description = "Región AWS donde se crea el bucket de estado."
  default     = "us-east-1"
}

variable "owner" {
  type        = string
  description = "Propietario del recurso. Usado en tags obligatorios."
  default     = "engineering"
}

variable "cost_center" {
  type        = string
  description = "Centro de costo para reportes de facturación."
  default     = "engineering"
}
