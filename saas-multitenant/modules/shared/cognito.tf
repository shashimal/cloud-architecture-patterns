# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${local.prefix}-user-pool"

  # Custom attribute to store tenantId on each user
  schema {
    name                     = "tenantId"
    attribute_data_type      = "String"
    mutable                  = false
    required                 = false
    string_attribute_constraints {
      min_length = 1
      max_length = 100
    }
  }

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 12
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  tags = {
    Name = "${local.prefix}-user-pool"
  }
}

resource "aws_cognito_user_pool_client" "api_client" {
  name         = "${local.prefix}-api-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  access_token_validity                = 60    # minutes
  id_token_validity                    = 60
  refresh_token_validity               = 30    # days
  prevent_user_existence_errors        = "ENABLED"

  read_attributes  = ["custom:tenantId", "email"]
  write_attributes = ["email"]

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}