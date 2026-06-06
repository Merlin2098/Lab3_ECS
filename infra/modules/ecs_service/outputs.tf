output "service_name" {
  description = "Nombre del servicio ECS."
  value       = aws_ecs_service.main.name
}

output "service_id" {
  description = "ID del servicio ECS."
  value       = aws_ecs_service.main.id
}
