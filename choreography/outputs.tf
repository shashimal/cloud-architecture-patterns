output "api_endpoint" {
  description = "HTTP API Gateway endpoint – POST /orders to place an order"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/orders"
}

output "event_bus_name" {
  description = "Custom EventBridge event bus name"
  value       = aws_cloudwatch_event_bus.orders.name
}

output "orders_table" {
  description = "DynamoDB table for orders"
  value       = aws_dynamodb_table.tables["orders"].name
}

output "inventory_table" {
  description = "DynamoDB table for inventory reservations"
  value       = aws_dynamodb_table.tables["inventory"].name
}

output "payments_table" {
  description = "DynamoDB table for payment records"
  value       = aws_dynamodb_table.tables["payments"].name
}

output "shipments_table" {
  description = "DynamoDB table for shipment records"
  value       = aws_dynamodb_table.tables["shipments"].name
}