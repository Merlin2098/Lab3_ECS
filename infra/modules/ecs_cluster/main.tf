resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  tags = var.tags
}
