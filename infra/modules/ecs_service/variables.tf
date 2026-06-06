variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como nombre del servicio ECS."
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)."
}

variable "cluster_id" {
  type        = string
  description = "ID del cluster ECS donde se desplegará el servicio. Output del módulo ecs_cluster."
}

variable "task_definition_arn" {
  type        = string
  description = "ARN de la Task Definition. Output del módulo ecs_task_definition."
}

variable "desired_count" {
  type        = number
  description = "Número de tasks Fargate que el servicio debe mantener en ejecución."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Lista de subnet IDs para la network_configuration. Output del módulo networking."
}

variable "security_group_id" {
  type        = string
  description = "ID del security group para las tasks. Output del módulo networking."
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a todos los recursos del módulo."
  default     = {}
}
