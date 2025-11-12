resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}-api-logs"
  kms_key_id        = aws_kms_key.shared_key.arn
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "api_handler_logs" {
  name              = "/aws/lambda/${var.project_name}-ApiHandler"
  kms_key_id        = aws_kms_key.shared_key.arn
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "vpc_builder_logs" {
  name              = "/aws/lambda/${var.project_name}-VpcBuilder"
  kms_key_id        = aws_kms_key.shared_key.arn
  retention_in_days = 7
}