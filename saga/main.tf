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

#Cancel order service
module "cancel_order" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "cancel-order"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path             = "${path.module}/lambda/cancel-order"
  local_existing_package  = "${path.module}/lambda/cancel-order.zip"

  create_role = false
  lambda_role = module.lambda_iam_role.arn

  environment_variables = {
    TABLE_NAME = "orders"
  }

  tags = {
    Name = "Cancel Order"
  }
}

#Charge payment service
module "charge_payment" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "charge-payment"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path             = "${path.module}/lambda/charge-payment"
  local_existing_package  = "${path.module}/lambda/charge-payment.zip"

  create_role = false
  lambda_role = module.lambda_iam_role.arn

  tags = {
    Name = "Charge Payment"
  }
}

#Charge payment service
module "refund_payment" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "refund-payment"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path             = "${path.module}/lambda/refund-payment"
  local_existing_package  = "${path.module}/lambda/refund-payment.zip"

  create_role = false
  lambda_role = module.lambda_iam_role.arn

  tags = {
    Name = "Refund Payment"
  }
}