# ─────────────────────────────────────────────────────────────────────────────
# Order Service IAM Role
# Needs: DynamoDB PutItem (orders), EventBridge PutEvents
# ─────────────────────────────────────────────────────────────────────────────

module "order_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "choreography-order-service-role"

  trust_policy_permissions = {
    TrustLambda = {
      actions    = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{ type = "Service", identifiers = ["lambda.amazonaws.com"] }]
    }
  }

  policies = {
    LambdaBasicExecution  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermision = aws_iam_policy.order_service.arn
  }

  tags = { Name = "choreography-order-service-role" }
}

resource "aws_iam_policy" "order_service" {
  name   = "choreography-order-service-policy"
  policy = data.aws_iam_policy_document.order_service.json
}

# ─────────────────────────────────────────────────────────────────────────────
# Inventory Service IAM Role
# Needs: DynamoDB PutItem (inventory), EventBridge PutEvents
# ─────────────────────────────────────────────────────────────────────────────

module "inventory_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "choreography-inventory-service-role"

  trust_policy_permissions = {
    TrustLambda = {
      actions    = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{ type = "Service", identifiers = ["lambda.amazonaws.com"] }]
    }
  }

  policies = {
    LambdaBasicExecution  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermision = aws_iam_policy.inventory_service.arn
  }

  tags = { Name = "choreography-inventory-service-role" }
}

resource "aws_iam_policy" "inventory_service" {
  name   = "choreography-inventory-service-policy"
  policy = data.aws_iam_policy_document.inventory_service.json
}

# ─────────────────────────────────────────────────────────────────────────────
# Payment Service IAM Role
# Needs: DynamoDB PutItem (payments), EventBridge PutEvents
# ─────────────────────────────────────────────────────────────────────────────

module "payment_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "choreography-payment-service-role"

  trust_policy_permissions = {
    TrustLambda = {
      actions    = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{ type = "Service", identifiers = ["lambda.amazonaws.com"] }]
    }
  }

  policies = {
    LambdaBasicExecution  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermision = aws_iam_policy.payment_service.arn
  }

  tags = { Name = "choreography-payment-service-role" }
}

resource "aws_iam_policy" "payment_service" {
  name   = "choreography-payment-service-policy"
  policy = data.aws_iam_policy_document.payment_service.json
}

# ─────────────────────────────────────────────────────────────────────────────
# Fulfillment Service IAM Role
# Needs: DynamoDB PutItem (shipments), EventBridge PutEvents
# ─────────────────────────────────────────────────────────────────────────────

module "fulfillment_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "choreography-fulfillment-service-role"

  trust_policy_permissions = {
    TrustLambda = {
      actions    = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{ type = "Service", identifiers = ["lambda.amazonaws.com"] }]
    }
  }

  policies = {
    LambdaBasicExecution  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermision = aws_iam_policy.fulfillment_service.arn
  }

  tags = { Name = "choreography-fulfillment-service-role" }
}

resource "aws_iam_policy" "fulfillment_service" {
  name   = "choreography-fulfillment-service-policy"
  policy = data.aws_iam_policy_document.fulfillment_service.json
}

# ─────────────────────────────────────────────────────────────────────────────
# Notification Service IAM Role
# Needs: CloudWatch Logs only (reads EventBridge events, no write-back needed)
# ─────────────────────────────────────────────────────────────────────────────

module "notification_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "notification-service-role"

  trust_policy_permissions = {
    TrustLambda = {
      actions    = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{ type = "Service", identifiers = ["lambda.amazonaws.com"] }]
    }
  }

  policies = {
    LambdaBasicExecution  = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermision = aws_iam_policy.notification_service.arn
  }

  tags = { Name = "choreography-notification-service-role" }
}

resource "aws_iam_policy" "notification_service" {
  name   = "choreography-notification-service-policy"
  policy = data.aws_iam_policy_document.notification_service.json
}
