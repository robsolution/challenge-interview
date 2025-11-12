# 1. KMS Key for encrypting logs and other resources
resource "aws_kms_key" "shared_key" {
  description             = "Shared KMS key for the project"
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms_policy.json
}