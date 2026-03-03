# ─────────────────────────────────────────────────────────────────────────────
# SNS Topic – receives published outbox events
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "order_events" {
  name = "order-events-topic"
  tags = { Name = "order-events-topic" }
}

resource "aws_sns_topic_subscription" "notifications" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notifications.arn
}
