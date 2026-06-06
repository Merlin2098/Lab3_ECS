resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.environment}"
  cluster         = var.cluster_id
  task_definition = var.task_definition_arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    # Las tasks usan subnets públicas de la VPC default. Requiere IP pública
    # para que ECS pueda descargar la imagen de ECR y enviar logs a CloudWatch.
    # En producción: usar subnets privadas con NAT Gateway o VPC Endpoints.
    assign_public_ip = true
  }

  tags = var.tags
}
