output "repository_url" {
  description = "URL completa del repositorio ECR. Usada por ecs_task_definition para referenciar la imagen."
  value       = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio ECR."
  value       = aws_ecr_repository.main.arn
}

output "repository_name" {
  description = "Nombre del repositorio ECR."
  value       = aws_ecr_repository.main.name
}
