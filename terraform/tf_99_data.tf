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