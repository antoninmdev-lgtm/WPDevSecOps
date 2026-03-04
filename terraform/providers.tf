terraform {
  backend "s3" {
    bucket         = "wpdevsecops-tfstate"
    key            = "state/terraform.tfstate" 
    region         = "eu-west-3"               
    encrypt        = true                      
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
