terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  common_tags = {
    Project     = var.project_name
    Environment = "bootstrap"
    Owner       = var.owner
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # force_destroy permite eliminar el bucket aunque tenga versiones del tfstate.
  # Requerido para terraform destroy en este lab — no usar en producción.
  force_destroy = true

  tags = local.common_tags
}

# El versioning se habilita deliberadamente: SPEC-003B lo requiere para
# recuperar versiones anteriores del state ante corrupción.
# Excepción justificada al "versioning off by default" de SPEC-009.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
