# ─────────────────────────────────────────────────────────────────────────────
# DynamoDB Tables
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "orders" {
  name         = "outbox-orders"
  hash_key     = "orderId"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "orderId"
    type = "S"
  }

  tags = { Name = "outbox-orders" }
}

resource "aws_dynamodb_table" "outbox_events" {
  name         = "outbox-events"
  hash_key     = "eventId"
  billing_mode = "PAY_PER_REQUEST"

  # Streams enabled so the outbox-processor Lambda is triggered on new events
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "eventId"
    type = "S"
  }

  tags = { Name = "outbox-events" }
}
