data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "tenant_dynamodb_access_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    resources = [
     module.tenant_access_role.arn
    ]
  }
}

data "aws_iam_policy_document" "tenant_access_role_policy_document" {

  statement {
    sid    = "TenantScopedDynamoAccess"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
    ]

    resources = [
      aws_dynamodb_table.tenant_data.arn,
      "${aws_dynamodb_table.tenant_data.arn}/index/*",
    ]

    # ForAllValues:StringLike — every key in the request must match the condition
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["$${aws:PrincipalTag/tenantId}"]
    }
  }

  statement {
    sid    = "DenyOtherTenantAccess"
    effect = "Deny"

    actions = ["dynamodb:*"]

    resources = [
      aws_dynamodb_table.tenant_data.arn,
      "${aws_dynamodb_table.tenant_data.arn}/index/*",
    ]

    # ForAnyValue:StringNotLike — deny if any key falls outside the tenant's partition
    condition {
      test     = "ForAnyValue:StringNotLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["$${aws:PrincipalTag/tenantId}"]
    }
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = "${path.module}/api-handler"
  output_path = "${path.module}/api-handler.zip"
}

