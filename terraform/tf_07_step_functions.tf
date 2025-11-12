# 1. Step Function State Machine
resource "aws_sfn_state_machine" "vpc_orchestrator" {
  name     = "${var.project_name}-VpcOrchestrator"
  role_arn = aws_iam_role.step_function_role.arn

  # Definition of the state machine (Amazon States Language)
  definition = <<EOT
{
  "Comment": "Orchestrates the creation of VPC via Lambda",
  "StartAt": "InvokeVpcBuilder",
  "States": {
    "InvokeVpcBuilder": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.vpc_builder.arn}",
        "Payload.$": "$"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Comment": "The Lambda function 'vpc_builder' itself updates DynamoDB in case of failure. This 'Catch' is a fallback.",
          "Next": "WorkflowFailed"
        }
      ],
      "Next": "WorkflowSucceeded"
    },
    "WorkflowFailed": {
      "Type": "Fail",
      "Cause": "The execution of Lambda 'vpc_builder' failed."
    },
    "WorkflowSucceeded": {
      "Type": "Succeed"
    }
  }
}
EOT

  tags = {
    Project = var.project_name
  }
}