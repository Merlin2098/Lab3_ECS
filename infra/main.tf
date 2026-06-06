# Orden de dependencias:
#
#   cloudwatch ──┐
#   ecr        ──┼──► ecs_task_definition ──┐
#   iam        ──┘                          ├──► ecs_service
#                                           │
#   ecs_cluster ────────────────────────────┤
#   networking  ────────────────────────────┘
#
# Las dependencias se resuelven por referencias output→input.
# No se requiere depends_on explícito.

module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "ecs_cluster" {
  source = "./modules/ecs_cluster"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "networking" {
  source = "./modules/networking"

  project_name   = var.project_name
  environment    = var.environment
  container_port = var.container_port
  tags           = local.common_tags
}

module "ecs_task_definition" {
  source = "./modules/ecs_task_definition"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  container_port     = var.container_port
  image_tag          = var.image_tag
  repository_url     = module.ecr.repository_url
  log_group_name     = module.cloudwatch.log_group_name
  execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn      = module.iam.task_role_arn
  tags               = local.common_tags
}

module "ecs_service" {
  source = "./modules/ecs_service"

  project_name        = var.project_name
  environment         = var.environment
  cluster_id          = module.ecs_cluster.cluster_id
  task_definition_arn = module.ecs_task_definition.task_definition_arn
  desired_count       = var.desired_count
  subnet_ids          = module.networking.subnet_ids
  security_group_id   = module.networking.security_group_id
  tags                = local.common_tags
}
