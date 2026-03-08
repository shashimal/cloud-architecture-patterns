# ─────────────────────────────────────────────────────────────────────────────
# DynamoDB Tables – one per microservice domain
# ─────────────────────────────────────────────────────────────────────────────

locals {
  dynamodb_tables = {
    orders    = { name = "choreography-orders",    hash_key = "orderId" }
    inventory = { name = "choreography-inventory", hash_key = "reservationId" }
    payments  = { name = "choreography-payments",  hash_key = "paymentId" }
    shipments = { name = "choreography-shipments", hash_key = "shipmentId" }
  }
}

resource "aws_dynamodb_table" "tables" {
  for_each     = local.dynamodb_tables

  name         = each.value.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key

  attribute {
    name = each.value.hash_key
    type = "S"
  }

  tags = { Name = each.value.name }
}