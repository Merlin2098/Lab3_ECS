data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task Execution Role: usado por ECS para descargar la imagen desde ECR
# y escribir logs en CloudWatch. Lo gestiona el plano de control de ECS.
resource "aws_iam_role" "task_execution" {
  name               = "${var.project_name}-${var.environment}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role: usado por el contenedor (la aplicación) una vez que está corriendo.
# Sin policies adicionales porque la app de este lab no llama a servicios AWS.
# En producción, este rol recibiría permisos específicos (ej. s3:GetObject).
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-${var.environment}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = var.tags
}
