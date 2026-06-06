# ECR
output "repository_url" {
  description = "URL completa del repositorio ECR. Usar para docker tag y docker push."
  value       = module.ecr.repository_url
}

output "repository_name" {
  description = "Nombre del repositorio ECR."
  value       = module.ecr.repository_name
}

# ECS
output "cluster_name" {
  description = "Nombre del cluster ECS."
  value       = module.ecs_cluster.cluster_name
}

output "cluster_arn" {
  description = "ARN del cluster ECS."
  value       = module.ecs_cluster.cluster_arn
}

output "service_name" {
  description = "Nombre del servicio ECS."
  value       = module.ecs_service.service_name
}

output "task_definition_family" {
  description = "Family name de la Task Definition."
  value       = module.ecs_task_definition.task_definition_family
}

# CloudWatch — obligación SPEC-009: exponer log_group_name y log_group_arn
output "log_group_name" {
  description = "Nombre del Log Group de CloudWatch donde ECS escribe los logs."
  value       = module.cloudwatch.log_group_name
}

output "log_group_arn" {
  description = "ARN del Log Group de CloudWatch."
  value       = module.cloudwatch.log_group_arn
}

# IAM
output "task_execution_role_arn" {
  description = "ARN del Task Execution Role."
  value       = module.iam.task_execution_role_arn
}

output "task_role_arn" {
  description = "ARN del Task Role."
  value       = module.iam.task_role_arn
}

# Networking
output "vpc_id" {
  description = "ID de la VPC utilizada."
  value       = module.networking.vpc_id
}

output "security_group_id" {
  description = "ID del security group de las tasks Fargate."
  value       = module.networking.security_group_id
}
