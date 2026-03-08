output "api_endpoint" {
  description = "HTTP API endpoint – POST to this URL to create an order"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/orders"
}

output "orders_table_name" {
  description = "DynamoDB table that stores orders"
  value       = aws_dynamodb_table.orders.name
}

output "outbox_table_name" {
  description = "DynamoDB table that stores outbox events (streams enabled)"
  value       = aws_dynamodb_table.outbox_events.name
}

output "sns_topic_arn" {
  description = "SNS topic that receives published order events"
  value       = aws_sns_topic.order_events.arn
}

output "sqs_queue_url" {
  description = "SQS queue consumed by the notification-service Lambda"
  value       = aws_sqs_queue.notifications.url
}

output "sqs_dlq_url" {
  description = "Dead-letter queue for failed notification messages"
  value       = aws_sqs_queue.notification_dlq.url
}
