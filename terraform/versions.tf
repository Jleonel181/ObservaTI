terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # Backend remoto (descomentar cuando se tenga bucket S3 para state)
  # backend "s3" {
  #   bucket         = "observati-terraform-state"
  #   key            = "phase1/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "observati-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ObservaTI"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
