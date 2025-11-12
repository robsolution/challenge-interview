resource "aws_kms_key" "shared_key" {
  description             = "Key CMK shared for encryption of resources"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}