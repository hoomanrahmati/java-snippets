provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  
  endpoints {
    # Storage
    s3 = "http://s3.localhost.localstack.cloud:4566"
    
    # Compute
    ec2 = "http://localhost:4566"
    
    # Databases
    dynamodb = "http://localhost:4566"
    rds = "http://localhost:4566"
    
    # Application Integration
    lambda = "http://localhost:4566"
    sqs = "http://localhost:4566"
    sns = "http://localhost:4566"
    sts  = "http://localhost:4566"
    
    # Management
    cloudwatch = "http://localhost:4566"
    iam = "http://localhost:4566"
    
    # API Gateway
    apigateway = "http://localhost:4566"
  }
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}