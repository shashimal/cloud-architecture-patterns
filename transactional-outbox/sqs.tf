# ─────────────────────────────────────────────────────────────────────────────
# SQS Queues – notification consumer
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sqs_queue" "notification_dlq" {
  name                      = "order-notification-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = { Name = "order-notification-dlq" }
}

resource "aws_sqs_queue" "notifications" {
  name                       = "order-notifications"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "order-notifications" }
}

# Allow SNS to publish messages into the SQS queue
resource "aws_sqs_queue_policy" "notifications" {
  queue_url = aws_sqs_queue.notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notifications.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.order_events.arn }
      }
    }]
  })
}
