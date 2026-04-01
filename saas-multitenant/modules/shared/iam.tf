module "backend_lambda_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name    = "backend-lambda-execution-role"

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
    TenantDynamoDBAccess = aws_iam_policy.tenant_dynamodb_access_policy.arn
  }

  tags = {
    Name = "Backend lambda execution role"
  }
}

resource "aws_iam_policy" "tenant_dynamodb_access_policy" {
  name   = "tenant-dynamodb-access-policy"
  policy = data.aws_iam_policy_document.tenant_dynamodb_access_policy_document.json
}


module "tenant_access_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"
  name = "tenant-access-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]
      principals = [{
        type        = "AWS"
        identifiers = [module.backend_lambda_execution_role.arn]
      }]
    }
  }

  policies = {
    TenantAccessPolicy = aws_iam_policy.tenant_access_role_policy.arn
  }
}

resource "aws_iam_policy" "tenant_access_role_policy" {
  name   = "tenant-access-role-policy"
  policy = data.aws_iam_policy_document.tenant_access_role_policy_document.json
}