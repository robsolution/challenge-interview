# 1. Lambda 'api_handler'
resource "aws_lambda_function" "api_handler" {
  function_name = "${var.project_name}-ApiHandler"
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.api_handler_role.arn

  filename         = data.archive_file.api_handler_zip.output_path
  source_code_hash = data.archive_file.api_handler_zip.output_base64sha256

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.vpc_orchestrator.id
      DYNAMODB_TABLE    = aws_dynamodb_table.vpc_requests.name
    }
  }

  tags = {
    Project = var.project_name
  }
}

# 2. Lambda 'vpc_builder'
resource "aws_lambda_function" "vpc_builder" {
  function_name = "${var.project_name}-VpcBuilder"
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.vpc_builder_role.arn
  timeout       = var.vpc_builder_timeout

  filename         = data.archive_file.vpc_builder_zip.output_path
  source_code_hash = data.archive_file.vpc_builder_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.vpc_requests.name
    }
  }

  tags = {
    Project = var.project_name
  }
}

