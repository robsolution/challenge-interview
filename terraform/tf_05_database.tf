resource "aws_dynamodb_table" "vpc_requests" {
  name         = "${var.project_name}-VpcRequests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.shared_key.arn
  }

  attribute {
    name = "job_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project = var.project_name
  }

  depends_on = [
    aws_kms_key.shared_key
  ]

}