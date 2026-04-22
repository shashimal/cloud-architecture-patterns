output "state_machine_arn" {
  description = "State machine arn"
  value       = aws_sfn_state_machine.scatter_gather_service.arn
}

output "scatter_gather_bucket_id" {
  description = "S3 bucket name for scatter-gather results"
  value       = module.scatter_gather_bucket.s3_bucket_id
}

output "scatter_gather_bucket_arn" {
  description = "S3 bucket ARN for scatter-gather results"
  value       = module.scatter_gather_bucket.s3_bucket_arn
}