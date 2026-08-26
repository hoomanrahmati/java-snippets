terraform {
  required_providers {
    aws = {
      # Instead of hashicorp/aws, use a local filesystem path
      source  = "local/aws"
      version = "5.82.2"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2 = "http://localhost:4566"
    ecs = "http://localhost:4566"
    s3  = "http://localhost:4566"
    # Add other services as needed
  }
}