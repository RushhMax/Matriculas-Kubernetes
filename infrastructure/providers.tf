terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto en S3 para el state
  backend "s3" {
  bucket       = "unsa-matricula-terraform-state-455290382075"
  key          = "foundation/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "unsa-matricula"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
