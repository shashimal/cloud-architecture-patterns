#Start -> Create Order -> Charge Payment -> Reserve Inventory -> Success | v Compensation Flow (Rollback)

#DynamoDB Table for orders
resource "aws_dynamodb_table" "orders" {
  name         = "orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"
  attribute {
    name = "order_id"
    type = "S"
  }
}

#Create order service
module "create_order" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "create-order"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path             = "${path.module}/lambda/create-order"
  local_existing_package  = "${path.module}/lambda/create-order.zip"

  create_role = false
  lambda_role = module.lambda_iam_role.arn

  environment_variables = {
    TABLE_NAME = "orders"
  }

  tags = {
    Name = "Create Order"
  }
}