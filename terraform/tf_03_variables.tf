variable "aws_region" {
  description = "A região da AWS onde os recursos serão criados."
  type        = string
}

variable "project_name" {
  description = "Um prefixo usado para nomear todos os recursos."
  type        = string
}

variable "environment" {
  description = "Timeout em segundos para a Lambda de criação da VPC."
  type        = string
}

variable "vpc_builder_timeout" {
  description = "Timeout em segundos para a Lambda de criação da VPC."
  type        = number
}