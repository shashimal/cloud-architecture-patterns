# ─────────────────────────────────────────────────────────────────────────────
# Lambda ZIP archives
# ─────────────────────────────────────────────────────────────────────────────

locals {
  archive_source_dirs = {
    order_service        = "order-service"
    inventory_service    = "inventory-service"
    payment_service      = "payment-service"
    fulfillment_service  = "fulfillment-service"
    notification_service = "notification-service"
  }
}

data "archive_file" "archives" {
  for_each = local.archive_source_dirs

  type        = "zip"
  source_dir  = "${path.module}/lambda/${each.value}"
  output_path = "${path.module}/lambda/${each.value}.zip"
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Policy Documents
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "order_service" {
  statement {
    sid       = "DynamoDBPutOrder"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tables["orders"].arn]
  }

  statement {
    sid       = "EventBridgePutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.orders.arn]
  }
}

data "aws_iam_policy_document" "inventory_service" {
  statement {
    sid       = "DynamoDBPutReservation"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tables["inventory"].arn]
  }

  statement {
    sid       = "EventBridgePutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.orders.arn]
  }
}

data "aws_iam_policy_document" "payment_service" {
  statement {
    sid       = "DynamoDBPutPayment"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tables["payments"].arn]
  }

  statement {
    sid       = "EventBridgePutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.orders.arn]
  }
}

data "aws_iam_policy_document" "fulfillment_service" {
  statement {
    sid       = "DynamoDBPutShipment"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tables["shipments"].arn]
  }

  statement {
    sid       = "EventBridgePutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.orders.arn]
  }
}

data "aws_iam_policy_document" "notification_service" {
  # Notification service only needs CloudWatch Logs (provided by AWSLambdaBasicExecutionRole)
  statement {
    sid       = "AllowLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}