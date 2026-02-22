module "lambda_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "common-lambda-role"

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
    LambdaBasicExecution = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    LambdaCustom         = aws_iam_policy.lambda_custom_policy.arn
  }

  tags = {
    Name = "Scatter Service IAM Role"
  }
}

resource "aws_iam_policy" "lambda_custom_policy" {
  name   = "lambda-custom-policy"
  policy = data.aws_iam_policy_document.lambda_permission.json
}

module "sfn_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name = "sfn-iam-role"
  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["states.amazonaws.com"]
      }]
    }
  }

  policies = {
    Lambda = aws_iam_policy.sfn_permission_policy.arn
  }

}

resource "aws_iam_policy" "sfn_permission_policy" {
  name   = "sfn-permission-policy"
  policy = data.aws_iam_policy_document.sfn_lambda_permission.json
}