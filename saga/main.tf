locals {

  services = {
    create-order = {
      name        = "create-order"
      description = "Create Order"
      environment_variables = {
        TABLE_NAME = "orders"
      }
    }

    cancel-order = {
      name        = "cancel-order"
      description = "Cancel Order"
      environment_variables = {
        TABLE_NAME = "orders"
      }
    }

    charge-payment = {
      name                  = "charge-payment"
      description           = "Charge Payment"
      environment_variables = {}
    }

    refund-payment = {
      name                  = "refund-payment"
      description           = "Refund Payment"
      environment_variables = {}
    }

    reserve-inventory = {
      name        = "reserve-inventory"
      description = "Reserve Inventory"
      environment_variables = {
        TABLE_NAME = "inventory"
      }
    }

    release-inventory = {
      name        = "release-inventory"
      description = "Release Inventory"
      environment_variables = {
        TABLE_NAME = "inventory"
      }
    }
  }

  tables = {
    orders = {
      name     = "orders"
      hash_key = "orderId"
      attribute = {
        name = "orderId"
        type = "S"
      }
    }
    inventory = {
      name     = "inventory"
      hash_key = "itemId"
      attribute = {
        name = "itemId"
        type = "S"
      }
    }
  }
}

#Start -> Create Order -> Charge Payment -> Reserve Inventory -> Success | v Compensation Flow (Rollback)

module "services" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  for_each      = local.services
  function_name = each.value.name
  handler       = "index.handler"
  runtime       = "nodejs24.x"

  source_path            = "${path.module}/lambda/${each.value.name}"
  local_existing_package = "${path.module}/lambda/${each.value.name}.zip"

  create_role = false
  lambda_role = module.lambda_iam_role.arn

  environment_variables = each.value.environment_variables
  tags = {
    Name        = each.value.name
    Description = each.value.description
  }
}

resource "aws_dynamodb_table" "this" {
  for_each = local.tables

  name         = each.value.name
  hash_key     = each.value.hash_key
  billing_mode = "PAY_PER_REQUEST"

  dynamic "attribute" {
    for_each = each.value.attribute != null ? [each.value.attribute] : []
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }
}

resource "aws_sfn_state_machine" "orchestrator" {
  name = "orchestrator-service"
  definition = templatefile("${path.module}/order-process2.asl.json", {
    create_order_arn      = module.services["create-order"].lambda_function_arn
    cancel_order_arn      = module.services["cancel-order"].lambda_function_arn
    charge_payment_arn    = module.services["charge-payment"].lambda_function_arn
    refund_payment_arn =  module.services["refund-payment"].lambda_function_arn
    reserve_inventory_arn = module.services["reserve-inventory"].lambda_function_arn
    release_inventory_arn = module.services["release-inventory"].lambda_function_arn
  })
  role_arn = module.sfn_iam_role.arn
}
