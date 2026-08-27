# # # --- Provider Configuration for LocalStack ---
# # provider "aws" {
# #   region                      = "us-east-1"
# #   access_key                  = "test"
# #   secret_key                  = "test"
# #   skip_credentials_validation = true
# #   skip_metadata_api_check     = true
# #   skip_requesting_account_id  = true
# #   s3_use_path_style           = true

# #   endpoints {
# #     ec2  = "http://localhost:4566"
# #     vpc  = "http://localhost:4566"
# #     iam  = "http://localhost:4566"
# #     sts  = "http://localhost:4566"
# #     # Add other endpoints as needed (e.g., s3, rds)
# #   }
# # }

# # --- Networking (Required for EC2) ---
# # A VPC to hold the instance [citation:8]
# resource "aws_vpc" "my_vpc" {
#   cidr_block = "10.0.0.0/16"
#   tags = { Name = "local-vpc" }
# }

# # A subnet within the VPC [citation:8]
# resource "aws_subnet" "public_subnet" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   map_public_ip_on_launch = true # Important for assigning a public IP for SSH/HTTP
#   tags = { Name = "local-subnet" }
# }

# # A Security Group to define network traffic rules [citation:1]
# resource "aws_security_group" "web_sg" {
#   name        = "allow-web-ssh"
#   description = "Allow SSH and HTTP traffic"
#   vpc_id      = aws_vpc.my_vpc.id

#   # Allow SSH for debugging
#   ingress {
#     description = "SSH from anywhere"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # Allow HTTP for web traffic
#   ingress {
#     description = "HTTP from anywhere"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # --- EC2 Instance ---
# # The main EC2 resource
# resource "aws_instance" "web_server" {
#   # LocalStack accepts any AMI ID; this is a standard placeholder [citation:3]
#   ami           = "ami-12345678"
#   instance_type = "t3.nano" # Or "t2.micro", but be aware of potential issues with burstable types [citation:10]

#   # Attach the instance to your networking components
#   subnet_id                   = aws_subnet.public_subnet.id
#   vpc_security_group_ids      = [aws_security_group.web_sg.id]
#   associate_public_ip_address = true

#   # User data script to install and run nginx on startup
#   user_data = <<-EOF
#     #!/bin/bash
#     apt-get update -y
#     apt-get install -y nginx
#     systemctl start nginx
#   EOF

#   tags = {
#     Name = "Local-Nginx-Server"
#   }
# }