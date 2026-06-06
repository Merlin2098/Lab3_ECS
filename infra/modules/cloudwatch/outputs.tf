output "log_group_name" {
  description = "Nombre del Log Group de CloudWatch. Usado por ecs_task_definition para configurar logConfiguration."
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "ARN del Log Group de CloudWatch."
  value       = aws_cloudwatch_log_group.ecs.arn
}
