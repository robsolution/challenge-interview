# 1. Cognito User Pool (for authentication)
resource "aws_cognito_user_pool" "user_pool" {
  name                     = "${var.project_name}-UserPool"
  auto_verified_attributes = ["email"]
}

# 2. Client User Pool (for allow apps to connect)
resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.project_name}-AppClient"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  # Enable username and password authentication flow (required for testing with AWS CLI)
  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  generate_secret     = false
}

# 3. Generate Password Random ---
resource "random_password" "test_user_password" {
  length  = 32
  special = true
}

# 4. Creation Test User ---
resource "aws_cognito_user" "test_user" {
  user_pool_id   = aws_cognito_user_pool.user_pool.id
  username       = "testuser@testdomain.com"
  message_action = "SUPPRESS"

  attributes = {
    email          = "testuser@testdomain.com"
    email_verified = true
  }

  depends_on = [random_password.test_user_password]
}

# 5. Set Password as Permanent ---
resource "null_resource" "set_user_password_permanently" {
  # It only runs after the user has been created.
  depends_on = [aws_cognito_user.test_user]

  # Provisioners execute commands.
  provisioner "local-exec" {
    command = <<EOT
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${aws_cognito_user_pool.user_pool.id} \
        --username ${aws_cognito_user.test_user.username} \
        --password '${random_password.test_user_password.result}' \
        --permanent
    EOT
  }
}