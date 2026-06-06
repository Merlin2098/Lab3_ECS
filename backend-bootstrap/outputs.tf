output "bucket_name" {
  description = "Nombre del bucket S3 creado para almacenar el Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "bucket_arn" {
  description = "ARN del bucket S3 de Terraform state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "region" {
  description = "Región AWS donde se creó el bucket."
  value       = data.aws_region.current.name
}
