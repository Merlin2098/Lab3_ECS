output "subnet_ids" {
  description = "Lista de subnet IDs de la VPC default. Usados por ecs_service para network_configuration."
  value       = data.aws_subnets.default.ids
}

output "security_group_id" {
  description = "ID del security group creado para las tasks Fargate."
  value       = aws_security_group.ecs_tasks.id
}

output "vpc_id" {
  description = "ID de la VPC utilizada (VPC default de la cuenta)."
  value       = data.aws_vpc.default.id
}
