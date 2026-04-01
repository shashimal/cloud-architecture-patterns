############ Backend Lambda function ########################
############################################################
module "backend_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "backend-lambda"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path            = "${path.module}/api-handler"
  local_existing_package = "${path.module}/api-handler.zip"

  create_role = false
  lambda_role = module.backend_lambda_execution_role.arn

  environment_variables = {
    TABLE_NAME        = aws_dynamodb_table.tenant_data.name
    TENANT_ACCESS_ROLE_ARN = module.tenant_access_role.arn
    ENVIRONMENT       = var.environment
  }
  tags = {
    Name = "backend-lambda-handler"
  }
}
