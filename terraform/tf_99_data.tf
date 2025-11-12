data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# 1. Compress the code of 'api_handler'
data "archive_file" "api_handler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/api_handler/"
  output_path = "${path.module}/.build/api_handler.zip"
}

# 2. Compress the code of 'vpc_builder'
data "archive_file" "vpc_builder_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/vpc_builder/"
  output_path = "${path.module}/.build/vpc_builder.zip"
}

# 3. KMS Key Policy
data "aws_iam_policy_document" "kms_policy" {
  # Default policy that allows root user to manage the key
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Statement to allow CloudWatch Logs to use the key
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.id}.amazonaws.com"]
    }
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
  }

  # Statement to allow API Gateway logging role to use the key
  statement {
    sid    = "AllowAPIGatewayLoggingRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.api_gateway_logging_role.arn]
    }
    actions   = ["kms:Encrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
  }

}
