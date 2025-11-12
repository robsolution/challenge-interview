resource "aws_dynamodb_table" "vpc_requests" {
  name         = "${var.project_name}-VpcRequests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}