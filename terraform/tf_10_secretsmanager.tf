# 1. Store Credentials in Secrets Manager ---
resource "aws_secretsmanager_secret" "cognito_creds" {
  name        = "${var.project_name}-TestUserCreds"
  description = "Cognito test user credentials for Project"
  kms_key_id  = aws_kms_key.shared_key.arn

  depends_on = [
    aws_kms_key.shared_key
  ]

}

resource "aws_secretsmanager_secret_version" "cognito_creds_version" {
  secret_id = aws_secretsmanager_secret.cognito_creds.id

  # Stores a JSON file containing the generated username and password
  secret_string = jsonencode({
    username = aws_cognito_user.test_user.username
    password = random_password.test_user_password.result
  })

  depends_on = [null_resource.set_user_password_permanently]
}