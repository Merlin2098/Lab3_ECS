data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Security group para tasks Fargate de ${var.project_name}"
  vpc_id      = data.aws_vpc.default.id

  tags = var.tags
}

resource "aws_security_group_rule" "ingress_app" {
  type              = "ingress"
  security_group_id = aws_security_group.ecs_tasks.id
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Acceso al puerto de la aplicación"
}

# Egress all traffic: permite descargar imágenes desde ECR y escribir logs en
# CloudWatch (ambos HTTPS/443). Simplificación de laboratorio.
# En producción: restringir a puertos 443 TCP solo hacia los endpoints necesarios.
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.ecs_tasks.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Salida irrestricta (lab). Restringir en producción."
}
