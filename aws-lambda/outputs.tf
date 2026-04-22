output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda_function.lambda_function_name
}

output "lambda_function_url" {
  description = "URL endpoint for the Lambda function"
  value       = aws_lambda_function_url.lambda_url.function_url
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.lambda_role.arn
}

output "lambda_cloudwatch_log_group" {
  description = "CloudWatch Log Group for the Lambda function"
  value       = "/aws/lambda/${var.function_name}"
}
