output "user_pool_id" {
  value = module.shared.user_pool_id
}

output "client_id" {
  value = module.shared.client_id
}

output "tenant_access_role_arn" {
  value = module.shared.tenant_access_role_arn
}
output "apigw_url" {
  value = module.shared.apigw_url
}