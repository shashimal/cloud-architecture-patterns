output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "client_id" {
  value = aws_cognito_user_pool_client.api_client.id
}

output "tenant_access_role_arn" {
  value = module.tenant_access_role.arn
}