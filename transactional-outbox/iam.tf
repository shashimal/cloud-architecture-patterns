# ─────────────────────────────────────────────────────────────────────────────
# Order Service IAM Role
# Needs: DynamoDB TransactWriteItems on both orders and outbox-events tables
# ─────────────────────────────────────────────────────────────────────────────

module "order_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "outbox-order-service-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
    }
  }

  policies = {
    LambdaBasicExecution   = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermisison = aws_iam_policy.order_service.arn
  }

  tags = {
    Name = "Order service IAM role"
  }
}

resource "aws_iam_policy" "order_service" {
  name   = "order-service-lambda-custom-policy"
  policy = data.aws_iam_policy_document.order_service.json
}

# ─────────────────────────────────────────────────────────────────────────────
# Outbox Processor IAM Role
# Needs: DynamoDB Streams read, UpdateItem on outbox table, SNS Publish
# ─────────────────────────────────────────────────────────────────────────────


module "outbox_processor_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "outbox-processor-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
    }
  }

  policies = {
    LambdaBasicExecution   = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermisison = aws_iam_policy.outbox_processor.arn
  }

  tags = {
    Name = "Outbox Processor IAM role"
  }
}


resource "aws_iam_policy" "outbox_processor" {
  name   = "outbox-processor-policy"
  policy = data.aws_iam_policy_document.outbox_processor.json
}


# ─────────────────────────────────────────────────────────────────────────────
# Notification Service IAM Role
# Needs: SQS ReceiveMessage, DeleteMessage, GetQueueAttributes
# ─────────────────────────────────────────────────────────────────────────────

module "notification_service_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "outbox-notification-service-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
    }
  }

  policies = {
    LambdaBasicExecution   = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPermisison = aws_iam_policy.notification_service.arn
  }

  tags = {
    Name = "Notification service IAM role"
  }
}


resource "aws_iam_policy" "notification_service" {
  name   = "outbox-notification-service-policy"
  policy = data.aws_iam_policy_document.notification_service.json
}
