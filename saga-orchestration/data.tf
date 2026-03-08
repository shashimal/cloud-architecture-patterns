
data "archive_file" "this" {
  for_each    = local.services
  type        = "zip"
  source_dir  = "${path.module}/lambda/${each.value.name}"
  output_path = "${path.module}/lambda/${each.value.name}.zip"
}

data "aws_iam_policy_document" "lambda_permission" {
  statement {
    sid    = "DynamodbPermission"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem"
    ]
    resources = values(aws_dynamodb_table.this)[*].arn
  }
}

data "aws_iam_policy_document" "sfn_lambda_permission" {
  statement {
    sid    = "LambdaInvokePermission"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = values(module.services)[*].lambda_function_arn

  }
}
