locals {
  prefix = "${var.app_name}-${var.environment}"
}

#DynamoDB Table (single table, all tenants)
resource aws_dynamodb_table "tenant_data" {
  name = "tanant-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenantId"

  attribute {
    name = "tenantId"
    type = "S"
  }
}