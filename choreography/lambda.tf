# ─────────────────────────────────────────────────────────────────────────────
# Lambda Functions
# ─────────────────────────────────────────────────────────────────────────────

locals {
  lambda_services = {
    order_service = {
      name        = "choreography-order-service"
      description = "Receives HTTP POST /orders, persists to DynamoDB, publishes order.placed event"
      source_dir  = "order-service"
      lambda_role = module.order_service_role.arn
      env_vars = {
        ORDERS_TABLE   = aws_dynamodb_table.tables["orders"].name
        EVENT_BUS_NAME = aws_cloudwatch_event_bus.orders.name
      }
    }
    inventory_service = {
      name        = "choreography-inventory-service"
      description = "Reacts to order.placed; reserves inventory; publishes inventory.reserved or inventory.failed"
      source_dir  = "inventory-service"
      lambda_role = module.inventory_service_role.arn
      env_vars = {
        INVENTORY_TABLE = aws_dynamodb_table.tables["inventory"].name
        EVENT_BUS_NAME  = aws_cloudwatch_event_bus.orders.name
      }
    }
    payment_service = {
      name        = "choreography-payment-service"
      description = "Reacts to inventory.reserved; processes payment; publishes payment.processed or payment.failed"
      source_dir  = "payment-service"
      lambda_role = module.payment_service_role.arn
      env_vars = {
        PAYMENTS_TABLE = aws_dynamodb_table.tables["payments"].name
        EVENT_BUS_NAME = aws_cloudwatch_event_bus.orders.name
      }
    }
    fulfillment_service = {
      name        = "choreography-fulfillment-service"
      description = "Reacts to payment.processed; creates shipment; publishes order.fulfilled"
      source_dir  = "fulfillment-service"
      lambda_role = module.fulfillment_service_role.arn
      env_vars = {
        SHIPMENTS_TABLE = aws_dynamodb_table.tables["shipments"].name
        EVENT_BUS_NAME  = aws_cloudwatch_event_bus.orders.name
      }
    }
    notification_service = {
      name        = "choreography-notification-service"
      description = "Reacts to all order lifecycle events and sends customer notifications"
      source_dir  = "notification-service"
      lambda_role = module.notification_service_role.arn
      env_vars    = {}
    }
  }
}

module "services" {
  source   = "terraform-aws-modules/lambda/aws"
  version  = "~> 8.0"
  for_each = local.lambda_services

  function_name          = each.value.name
  description            = each.value.description
  handler                = "index.handler"
  runtime                = "nodejs24.x"

  source_path            = "${path.module}/lambda/${each.value.source_dir}"
  local_existing_package = "${path.module}/lambda/${each.value.source_dir}.zip"

  create_role = false
  lambda_role = each.value.lambda_role

  environment_variables = each.value.env_vars

  depends_on = [data.archive_file.archives]

  tags = { Name = each.value.name }
}