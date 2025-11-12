resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}-api-logs"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "api_handler_logs" {
  name              = "/aws/lambda/${var.project_name}-ApiHandler"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "vpc_builder_logs" {
  name              = "/aws/lambda/${var.project_name}-VpcBuilder"
  retention_in_days = 7
}