# ─────────────────────────────────────────────────────────────────────────────
# Lambda Functions
# ─────────────────────────────────────────────────────────────────────────────

module "order_service" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "order-service"
  description   = "Atomically creates an order and an outbox event via DynamoDB TransactWriteItems"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path            = "${path.module}/lambda/order-service"
  local_existing_package = "${path.module}/lambda/order-service.zip"

  create_role = false
  lambda_role = module.order_service_role.arn

  environment_variables = {
    ORDERS_TABLE = aws_dynamodb_table.orders.name
    OUTBOX_TABLE = aws_dynamodb_table.outbox_events.name
  }

  depends_on = [data.archive_file.order_service]

  tags = { Name = "order-service" }
}

module "outbox_processor" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "outbox-processor"
  description   = "Triggered by DynamoDB Streams; publishes outbox events to SNS"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path            = "${path.module}/lambda/outbox-processor"
  local_existing_package = "${path.module}/lambda/outbox-processor.zip"

  create_role = false
  lambda_role = module.outbox_processor_role.arn

  environment_variables = {
    OUTBOX_TABLE  = aws_dynamodb_table.outbox_events.name
    SNS_TOPIC_ARN = aws_sns_topic.order_events.arn
  }

  depends_on = [data.archive_file.outbox_processor]

  tags = { Name = "outbox-processor" }
}

module "notification_service" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "notification-service"
  description   = "Consumes order events from SQS (simulates sending customer notifications)"
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path            = "${path.module}/lambda/notification-service"
  local_existing_package = "${path.module}/lambda/notification-service.zip"

  create_role = false
  lambda_role = module.notification_service_role.arn

  environment_variables = {
    ORDERS_TABLE = aws_dynamodb_table.orders.name
  }

  depends_on = [data.archive_file.notification_service]

  tags = { Name = "notification-service" }
}


# ─────────────────────────────────────────────────────────────────────────────
# Event Source Mappings
# ─────────────────────────────────────────────────────────────────────────────

# DynamoDB Streams → outbox-processor
resource "aws_lambda_event_source_mapping" "outbox_processor" {
  event_source_arn  = aws_dynamodb_table.outbox_events.stream_arn
  function_name     = module.outbox_processor.lambda_function_arn
  starting_position = "LATEST"
  batch_size        = 10

  depends_on = [module.outbox_processor]
}

# SQS → notification-service
resource "aws_lambda_event_source_mapping" "notification_service" {
  event_source_arn = aws_sqs_queue.notifications.arn
  function_name    = module.notification_service.lambda_function_arn
  batch_size       = 5

  depends_on = [module.notification_service]
}
