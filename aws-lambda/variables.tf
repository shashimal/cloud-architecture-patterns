variable "aws_region" {
  description = "AWS region for deploying the Lambda function"
  type        = string
  default     = "ap-southeast-1"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "hello-world-lambda"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}
