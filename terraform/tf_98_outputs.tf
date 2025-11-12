output "api_gateway_invoke_url" {
  description = "The base URL to invoke the API."
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "cognito_user_pool_id" {
  description = "The Cognito User Pool ID."
  value       = aws_cognito_user_pool.user_pool.id
}

output "cognito_app_client_id" {
  description = "The Cognito App Client ID."
  value       = aws_cognito_user_pool_client.app_client.id
}

output "user_secret_arn" {
  description = "The ARN of the secret in Secrets Manager containing the test user's credentials."
  value       = aws_secretsmanager_secret.cognito_creds.arn
}