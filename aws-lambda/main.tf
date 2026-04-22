# ─────────────────────────────────────────────────────────────────────────────
# AWS Lambda Function
# A simple serverless function demonstrating best practices
# ─────────────────────────────────────────────────────────────────────────────

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda.zip"
}

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = var.function_name
  description   = "A simple Lambda function deployed with Terraform"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]

  memory_size = 128
  timeout     = 30

  source_path            = "${path.module}/src"
  local_existing_package = "${path.module}/lambda.zip"

  create_role = false
  lambda_role = module.lambda_role.arn

  environment_variables = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = "INFO"
  }

  cloudwatch_logs_retention_in_days = var.log_retention_days

  depends_on = [data.archive_file.lambda_zip]

  tags = {
    Name        = var.function_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Lambda Function URL (Optional - for HTTP access without API Gateway)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = module.lambda_function.lambda_function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["*"]
    max_age       = 86400
  }
}
