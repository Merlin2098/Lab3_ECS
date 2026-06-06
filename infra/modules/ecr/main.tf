resource "aws_ecr_repository" "main" {
  name = "${var.project_name}-${var.environment}"

  # force_delete permite eliminar el repositorio aunque contenga imágenes.
  # Simplificación de laboratorio — no usar en producción.
  force_delete = true

  tags = var.tags
}
