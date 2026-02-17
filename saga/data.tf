data "archive_file" "create_order_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/create-order"
  output_path = "${path.module}/lambda/create-order.zip"
}

data "archive_file" "cancel_order_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/cancel-order"
  output_path = "${path.module}/lambda/cancel-order.zip"
}

data "archive_file" "charge_payment_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/charge-payment"
  output_path = "${path.module}/lambda/charge-payment.zip"
}

data "archive_file" "refund_payment_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/refund-payment"
  output_path = "${path.module}/lambda/refund-payment.zip"
}

data "archive_file" "reserve_inventory_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/reserve-inventory"
  output_path = "${path.module}/lambda/reserve-inventory.zip"
}

data "archive_file" "release_inventory_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/release-inventory"
  output_path = "${path.module}/lambda/release-inventory.zip"
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
    resources = [
      aws_dynamodb_table.orders.arn,
      aws_dynamodb_table.inventory.arn
    ]
  }
}
