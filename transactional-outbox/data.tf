# ─────────────────────────────────────────────────────────────────────────────
# Lambda ZIP archives
# ─────────────────────────────────────────────────────────────────────────────

data "archive_file" "order_service" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/order-service"
  output_path = "${path.module}/lambda/order-service.zip"
}

data "archive_file" "outbox_processor" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/outbox-processor"
  output_path = "${path.module}/lambda/outbox-processor.zip"
}

data "archive_file" "notification_service" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/notification-service"
  output_path = "${path.module}/lambda/notification-service.zip"
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Policy Documents
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "order_service" {
  statement {
    sid    = "DynamoDBTransactWrite"
    effect = "Allow"
    actions = [
      "dynamodb:TransactWriteItems",
      "dynamodb:PutItem"
    ]
    resources = [
      aws_dynamodb_table.orders.arn,
      aws_dynamodb_table.outbox_events.arn,
    ]
  }
}

data "aws_iam_policy_document" "outbox_processor" {
  # Read shard data — scoped to this specific stream
  statement {
    sid    = "DynamoDBStreamRead"
    effect = "Allow"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
    ]
    resources = [aws_dynamodb_table.outbox_events.stream_arn]
  }

  # ListStreams is a table-level operation — cannot be scoped to a stream ARN
  statement {
    sid       = "DynamoDBListStreams"
    effect    = "Allow"
    actions   = ["dynamodb:ListStreams"]
    resources = ["*"]
  }

  # Mark outbox events as PUBLISHED
  statement {
    sid       = "DynamoDBUpdateOutbox"
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.outbox_events.arn]
  }

  # Publish events to SNS
  statement {
    sid       = "SNSPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.order_events.arn]
  }
}

data "aws_iam_policy_document" "notification_service" {
  # Consume messages from the SQS notification queue
  statement {
    sid    = "SQSConsume"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.notifications.arn]
  }

  # Update order status to NOTIFIED after sending the notification
  statement {
    sid       = "DynamoDBUpdateOrder"
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.orders.arn]
  }
}
