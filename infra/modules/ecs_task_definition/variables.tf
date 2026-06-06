variable "project_name" {
  type        = string
  description = "Nombre base del proyecto. Se usa como family name y nombre del contenedor."
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue (dev, staging, prod)."
}

variable "aws_region" {
  type        = string
  description = "Región AWS. Requerida por la configuración awslogs de CloudWatch."
}

variable "task_cpu" {
  type        = number
  description = "CPU asignada a la Task Definition en unidades ECS (256 = 0.25 vCPU)."
}

variable "task_memory" {
  type        = number
  description = "Memoria asignada a la Task Definition en MB."
}

variable "container_port" {
  type        = number
  description = "Puerto expuesto por el contenedor."
}

variable "image_tag" {
  type        = string
  description = "Tag de la imagen Docker en ECR."
}

variable "repository_url" {
  type        = string
  description = "URL del repositorio ECR. Output del módulo ecr."
}

variable "log_group_name" {
  type        = string
  description = "Nombre del Log Group de CloudWatch. Output del módulo cloudwatch."
}

variable "execution_role_arn" {
  type        = string
  description = "ARN del Task Execution Role IAM. Output del módulo iam."
}

variable "task_role_arn" {
  type        = string
  description = "ARN del Task Role IAM. Output del módulo iam."
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a todos los recursos del módulo."
  default     = {}
}
