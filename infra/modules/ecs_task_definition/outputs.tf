output "task_definition_arn" {
  description = "ARN completo de la Task Definition (incluye revisión). Usado por ecs_service."
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "Family name de la Task Definition."
  value       = aws_ecs_task_definition.main.family
}
