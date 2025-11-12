terraform {
  backend "s3" {
    bucket = "terraform-tfstate-913974722485"
    key    = "challenge-interview/terraform.tfstate"
    region = "sa-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}