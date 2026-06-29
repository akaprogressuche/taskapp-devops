terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # storing state in S3 so it doesn't get lost if something happens to my laptop
  backend "s3" {
    bucket      = "capstone-phoenix-state-059771369098"
    key         = "capstone/cluster/terraform.tfstate"
    region      = "us-east-1"
    use_lockfile = true
    encrypt     = true
  }
}

provider "aws" {
  region = var.aws_region
}
