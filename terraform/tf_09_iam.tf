# 1. Role for Lambda 'api_handler'
resource "aws_iam_role" "api_handler_role" {
  name = "${var.project_name}-ApiHandlerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# 2. Policy for the Lambda 'api_handler'
resource "aws_iam_policy" "api_handler_policy" {
  name = "${var.project_name}-ApiHandlerPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Logs permission
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # Permission to interact with the DynamoDB table.
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.vpc_requests.arn
      },
      {
        # Permission to start the Step Function
        Action   = "states:StartExecution"
        Effect   = "Allow"
        Resource = aws_sfn_state_machine.vpc_orchestrator.id
      }
    ]
  })
}

# 3. Attach the policy to the role.
resource "aws_iam_role_policy_attachment" "api_handler_attach" {
  role       = aws_iam_role.api_handler_role.name
  policy_arn = aws_iam_policy.api_handler_policy.arn
}

# --- Lambda Role 'vpc_builder' ---

# 4. Role for Lambda 'vpc_builder'
resource "aws_iam_role" "vpc_builder_role" {
  name = "${var.project_name}-VpcBuilderRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# 5. Lambda policy 'vpc_builder'
resource "aws_iam_policy" "vpc_builder_policy" {
  name = "${var.project_name}-VpcBuilderPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Logs permission
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # DynamoDB table permission for update
        Action   = "dynamodb:UpdateItem"
        Effect   = "Allow"
        Resource = aws_dynamodb_table.vpc_requests.arn
      },
      {
        # EC2 permissions to create the VPC and its components.
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateVpc",
          "ec2:DescribeVpcs",
          "ec2:CreateSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateTags",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:AssociateRouteTable",
          "ec2:CreateRoute",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:ModifySubnetAttribute",
          "ec2:AllocateAddress",
          "ec2:CreateNatGateway",
          "ec2:DescribeNatGateways"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# 6. Attach the policy on role
resource "aws_iam_role_policy_attachment" "vpc_builder_attach" {
  role       = aws_iam_role.vpc_builder_role.name
  policy_arn = aws_iam_policy.vpc_builder_policy.arn
}

# --- Step Function Role ---

# 7. State Machine Role (Step Function)
resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-StepFunctionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })
}

# 8. Policy for Step Function
resource "aws_iam_policy" "step_function_policy" {
  name = "${var.project_name}-StepFunctionPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permission to Lambda invoke 'vpc_builder'
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.vpc_builder.arn
      }
    ]
  })
}

# 9. Attach the policy on role
resource "aws_iam_role_policy_attachment" "step_function_attach" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}