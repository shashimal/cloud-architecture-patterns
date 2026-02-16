data "archive_file" "create_order_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/create-order"
  output_path = "${path.module}/lambda/create-order.zip"
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
    resources = [aws_dynamodb_table.orders.arn]
  }
}
