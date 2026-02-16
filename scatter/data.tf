data "aws_iam_policy_document" "step_function_lambda_policy_document" {
  statement {
    sid = "LambdaInvokePermission"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      module.worker_service.lambda_function_arn,
      module.aggregator_service.lambda_function_arn
    ]
  }
}
