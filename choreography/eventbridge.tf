locals {
  event_rules = {
    order_placed = {
      name        = "choreography-order-placed"
      description = "Routes order.placed events to Inventory and Notification services"
      source      = "ecommerce.order-service"
      detail_type = "order.placed"
    }
    inventory_reserved = {
      name        = "choreography-inventory-reserved"
      description = "Routes inventory.reserved events to Payment and Notification services"
      source      = "ecommerce.inventory-service"
      detail_type = "inventory.reserved"
    }
    inventory_failed = {
      name        = "choreography-inventory-failed"
      description = "Routes inventory.failed events to Notification service"
      source      = "ecommerce.inventory-service"
      detail_type = "inventory.failed"
    }
    payment_processed = {
      name        = "choreography-payment-processed"
      description = "Routes payment.processed events to Fulfillment and Notification services"
      source      = "ecommerce.payment-service"
      detail_type = "payment.processed"
    }
    payment_failed = {
      name        = "choreography-payment-failed"
      description = "Routes payment.failed events to Notification service"
      source      = "ecommerce.payment-service"
      detail_type = "payment.failed"
    }
    order_fulfilled = {
      name        = "choreography-order-fulfilled"
      description = "Routes order.fulfilled events to Notification service"
      source      = "ecommerce.fulfillment-service"
      detail_type = "order.fulfilled"
    }
  }

  # Each entry: { rule_key, target_id, lambda_arn }
  event_targets = {
    order_placed_inventory = {
      rule      = "order_placed"
      target_id = "inventory-service"
      arn       = module.services["inventory_service"].lambda_function_arn
    }
    order_placed_notification = {
      rule      = "order_placed"
      target_id = "notification-service-order-placed"
      arn       = module.services["notification_service"].lambda_function_arn
    }
    inventory_reserved_payment = {
      rule      = "inventory_reserved"
      target_id = "payment-service"
      arn       = module.services["payment_service"].lambda_function_arn
    }
    inventory_reserved_notification = {
      rule      = "inventory_reserved"
      target_id = "notification-service-inventory-reserved"
      arn       = module.services["notification_service"].lambda_function_arn
    }
    inventory_failed_notification = {
      rule      = "inventory_failed"
      target_id = "notification-service-inventory-failed"
      arn       = module.services["notification_service"].lambda_function_arn
    }
    payment_processed_fulfillment = {
      rule      = "payment_processed"
      target_id = "fulfillment-service"
      arn       = module.services["fulfillment_service"].lambda_function_arn
    }
    payment_processed_notification = {
      rule      = "payment_processed"
      target_id = "notification-service-payment-processed"
      arn       = module.services["notification_service"].lambda_function_arn
    }
    payment_failed_notification = {
      rule      = "payment_failed"
      target_id = "notification-service-payment-failed"
      arn       = module.services["notification_service"].lambda_function_arn
    }
    order_fulfilled_notification = {
      rule      = "order_fulfilled"
      target_id = "notification-service-order-fulfilled"
      arn       = module.services["notification_service"].lambda_function_arn
    }
  }

  # Each entry: { statement_id, function_name, rule_key }
  lambda_permissions = {
    inventory_order_placed = {
      statement_id  = "AllowEBInvokeInventory"
      function_name = module.services["inventory_service"].lambda_function_name
      rule          = "order_placed"
    }
    payment_inventory_reserved = {
      statement_id  = "AllowEBInvokePayment"
      function_name = module.services["payment_service"].lambda_function_name
      rule          = "inventory_reserved"
    }
    fulfillment_payment_processed = {
      statement_id  = "AllowEBInvokeFulfillment"
      function_name = module.services["fulfillment_service"].lambda_function_name
      rule          = "payment_processed"
    }
    notification_order_placed = {
      statement_id  = "AllowEBInvokeNotificationOrderPlaced"
      function_name = module.services["notification_service"].lambda_function_name
      rule          = "order_placed"
    }
    notification_inventory_reserved = {
      statement_id  = "AllowEBInvokeNotificationInventoryReserved"
      function_name = module.services["notification_service"].lambda_function_name
      rule          = "inventory_reserved"
    }
    notification_inventory_failed = {
      statement_id  = "AllowEBInvokeNotificationInventoryFailed"
      function_name = module.services["notification_service"].lambda_function_name
      rule          = "inventory_failed"
    }
    notification_payment_processed = {
      statement_id  = "AllowEBInvokeNotificationPaymentProcessed"
      function_name = module.services["notification_service"].lambda_function_name
      rule          = "payment_processed"
    }
    notification_payment_failed = {
      statement_id  = "AllowEBInvokeNotificationPaymentFailed"
      function_name = module.services["notification_service"].lambda_function_name
      rule          = "payment_failed"
    }
    notification_order_fulfilled = {
      statement_id  = "AllowEBInvokeNotificationOrderFulfilled"
      function_name = module.services["notification_service"].lambda_function_name
      rule          = "order_fulfilled"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Custom EventBridge Event Bus
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_bus" "orders" {
  name = "ecommerce-orders"
  tags = { Name = "ecommerce-orders" }
}

# ─────────────────────────────────────────────────────────────────────────────
# Event Rules
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "rules" {
  for_each = local.event_rules

  name           = each.value.name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  description    = each.value.description

  event_pattern = jsonencode({
    source      = [each.value.source]
    detail-type = [each.value.detail_type]
  })

  tags = { Name = each.value.name }
}

# ─────────────────────────────────────────────────────────────────────────────
# Event Targets
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_target" "targets" {
  for_each = local.event_targets

  rule           = aws_cloudwatch_event_rule.rules[each.value.rule].name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  target_id      = each.value.target_id
  arn            = each.value.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# EventBridge → Lambda Permissions
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_lambda_permission" "eb_invoke" {
  for_each = local.lambda_permissions

  statement_id  = each.value.statement_id
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rules[each.value.rule].arn
}