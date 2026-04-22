# ─────────────────────────────────────────────────────────────────────────────
# Lambda Execution IAM Role
# Provides basic execution permissions for CloudWatch Logs
# ─────────────────────────────────────────────────────────────────────────────

module "lambda_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "${var.function_name}-role"

  trust_policy_permissions = {
    TrustLambda = {
      actions    = ["sts:AssumeRole", "sts:TagSession"]
      principals = [{ type = "Service", identifiers = ["lambda.amazonaws.com"] }]
    }
  }

  policies = {
    LambdaBasicExecution = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustomPolicy   = aws_iam_policy.lambda_custom.arn
  }

  tags = {
    Name        = "${var.function_name}-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "lambda_custom" {
  name        = "${var.function_name}-policy"
  description = "Custom policy for Lambda function"
  policy      = data.aws_iam_policy_document.lambda_custom.json
}

data "aws_iam_policy_document" "lambda_custom" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}
