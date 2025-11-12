# 1. API Gateway (REST API)
resource "aws_api_gateway_rest_api" "vpc_api" {
  name        = "${var.project_name}-Api"
  description = "API for VPC's provision"
}

# 2. API Gateway Authorizator (conected on Cognito)
resource "aws_api_gateway_authorizer" "cognito_auth" {
  name          = "${var.project_name}-CognitoAuth"
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.user_pool.arn]
}

# 3. Resources /vpc
resource "aws_api_gateway_resource" "vpc_resource" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  parent_id   = aws_api_gateway_rest_api.vpc_api.root_resource_id
  path_part   = "vpc"
}

# 4. POST Method /vpc
resource "aws_api_gateway_method" "post_vpc" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  resource_id   = aws_api_gateway_resource.vpc_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

# 5. POST Integration /vpc with Lambda 'api_handler'
resource "aws_api_gateway_integration" "post_vpc_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vpc_api.id
  resource_id             = aws_api_gateway_resource.vpc_resource.id
  http_method             = aws_api_gateway_method.post_vpc.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

# 6. Resource /vpc/{job_id}
resource "aws_api_gateway_resource" "vpc_job_resource" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id
  parent_id   = aws_api_gateway_resource.vpc_resource.id
  path_part   = "{job_id}"
}

# 7. GET Method /vpc/{job_id}
resource "aws_api_gateway_method" "get_vpc_job" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_api.id
  resource_id   = aws_api_gateway_resource.vpc_job_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
}

# 8. GET Integration /vpc/{job_id} com a Lambda 'api_handler'
resource "aws_api_gateway_integration" "get_vpc_job_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vpc_api.id
  resource_id             = aws_api_gateway_resource.vpc_job_resource.id
  http_method             = aws_api_gateway_method.get_vpc_job.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

# 9. API Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.vpc_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.vpc_resource.id,
      aws_api_gateway_method.post_vpc.id,
      aws_api_gateway_integration.post_vpc_integration.id,
      aws_api_gateway_resource.vpc_job_resource.id,
      aws_api_gateway_method.get_vpc_job.id,
      aws_api_gateway_integration.get_vpc_job_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 10. Stage (ex: 'dev', 'nprod' or 'prod')
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id        = aws_api_gateway_deployment.api_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.vpc_api.id
  stage_name           = var.environment
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      path                    = "$context.path"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      authorizerPrincipalId   = "$context.authorizer.principalId"
    })
  }

  depends_on = [
    aws_api_gateway_account.current
  ]
  
}

# 11. API Gateway permission to Lambda invoke 'api_handler'
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"

  # Allows any method at any stage of the API to invoke a Lambda.
  source_arn = "${aws_api_gateway_rest_api.vpc_api.execution_arn}/*/*"
}

# 12. Associate the log role with the account (required for APIGW v1)
resource "aws_api_gateway_account" "current" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logging_role.arn
  depends_on = [
    aws_iam_role_policy_attachment.api_gateway_logging_attach
  ]
}