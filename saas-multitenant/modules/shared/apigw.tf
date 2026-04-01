resource "aws_api_gateway_rest_api" "main" {
  name        = "multi-tenant-api"
  description = "Multi-tenant SaaS API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${local.prefix}-cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.main.arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  # Forward the Authorization header so Lambda can inspect raw claims if needed
  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "lambda_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "POST"          # Lambda invoke is always POST
  type        = "AWS_PROXY"
  uri         = module.backend_lambda.lambda_function_invoke_arn
}

# because the invoke call is rejected by Lambda's resource policy.
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.backend_lambda.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Restrict to invocations from this specific API only.
  # Format: arn:aws:execute-api:{region}:{account}:{api-id}/*/*/*
  source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_method.proxy_any,
    aws_api_gateway_integration.lambda_proxy,
  ]

  # Force a new deployment when the integration config changes.
  # Without this, Terraform may skip re-deployment after integration updates.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_integration.lambda_proxy.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage — the live URL endpoint (e.g. https://{id}.execute-api.{region}.amazonaws.com/prod)
resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id
  stage_name    = var.environment

  # Enable X-Ray tracing at the API GW layer as well
  xray_tracing_enabled = true

  # Access logging — one log group for all tenants at the API GW level.
  # Per-tenant filtering is done via Log Insights using the tenantId field
  # emitted by the Lambda structured logs.
  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.apigw_access_logs.arn
  #   format = jsonencode({
  #     requestId      = "$context.requestId"
  #     ip             = "$context.identity.sourceIp"
  #     caller         = "$context.identity.caller"
  #     user           = "$context.identity.user"
  #     requestTime    = "$context.requestTime"
  #     httpMethod     = "$context.httpMethod"
  #     resourcePath   = "$context.resourcePath"
  #     status         = "$context.status"
  #     protocol       = "$context.protocol"
  #     responseLength = "$context.responseLength"
  #     # Cognito claims injected by the authorizer
  #     tenantId       = "$context.authorizer.claims.custom:tenantId"
  #   })
  # }

  tags = {
    Name = "${local.prefix}-api-stage"
  }
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "apigw_access_logs" {
  name              = "/aws/apigateway/${local.prefix}"
  retention_in_days = 30

  tags = {
    Name = "${local.prefix}-apigw-access-logs"
  }
}
