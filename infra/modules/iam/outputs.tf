output "task_execution_role_arn" {
  description = "ARN del ECS Task Execution Role. Requerido por la Task Definition."
  value       = aws_iam_role.task_execution.arn
}

output "task_execution_role_name" {
  description = "Nombre del ECS Task Execution Role."
  value       = aws_iam_role.task_execution.name
}

output "task_role_arn" {
  description = "ARN del ECS Task Role. Requerido por la Task Definition."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Nombre del ECS Task Role."
  value       = aws_iam_role.task.name
}
