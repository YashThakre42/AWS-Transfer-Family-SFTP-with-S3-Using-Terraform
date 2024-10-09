provider "aws" {
  region = "eu-central-1"  # Replace with your region if needed
}


# 1. Created an S3 bucket
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = "ygt-sftp-s3-terraform"
}


# 2. Created an IAM Policy with S3 permissions
resource "aws_iam_policy" "sftp_s3_policy" {
  name        = "ygt-sftp-s3-policy-terraform"
  description = "IAM policy for S3 access in Transfer Family"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        Resource = [
          aws_s3_bucket.sftp_bucket.arn,
          "${aws_s3_bucket.sftp_bucket.arn}/*"
        ]
      }
    ]
  })
}


# 3. Created an IAM Role for AWS Transfer Family 
resource "aws_iam_role" "sftp_transfer_role" {
  name = "ygt-sftp-s3-role-terraform"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "transfer.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
# Attached the policy to the role
resource "aws_iam_role_policy_attachment" "sftp_role_policy_attachment" {
  role       = aws_iam_role.sftp_transfer_role.name
  policy_arn = aws_iam_policy.sftp_s3_policy.arn
}


# 4. Created VPC for AWS Transfer Family Server
resource "aws_vpc" "sftp_vpc" {
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "SFTP-VPC"
  }
}
resource "aws_subnet" "sftp_subnet" {
  vpc_id            = aws_vpc.sftp_vpc.id
  cidr_block        = "10.0.1.0/28"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "SFTP-Subnet"
  }
}

# Created Security Group for the Transfer Server
resource "aws_security_group" "sftp_sg" {
  vpc_id = aws_vpc.sftp_vpc.id
  name   = "SFTP-Security-Group"

  # Allow inbound SFTP (port 22) traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SFTP-SG"
  }
}

# 5. Create AWS Transfer Family Server with VPC endpoint, S3 domain, and a new role
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "SERVICE_MANAGED"  # Service managed identity provider
  endpoint_type          = "VPC"              # VPC-hosted endpoint
  protocols              = ["SFTP"]           # SFTP protocol
  domain                 = "S3"               # S3 storage domain

  # Specify the VPC, subnet, and security group for the VPC endpoint
  endpoint_details {
    vpc_id          = aws_vpc.sftp_vpc.id
    subnet_ids      = [aws_subnet.sftp_subnet.id]
    security_group_ids = [aws_security_group.sftp_sg.id]
  }
  tags = {
    Name = "YGT-SFTP-Transfer-Server-terraform"
  }
}

# 6. Create a user for the AWS Transfer Family
resource "aws_transfer_user" "sftp_user" {
  server_id     = aws_transfer_server.sftp_server.id
  user_name     = "ygt-terraform"
  role          = aws_iam_role.sftp_transfer_role.arn

  # Set the home directory for the user in the S3 bucket
  home_directory = "/ygt/terraform"

  # Home directory mapping for advanced directory management(User will be directede to the specefied location, rather than home directory, if users wants to hide some files)
  #home_directory_mappings = [
   # {
    #  entry  = "/documents"                                                        #The entry point for the user when they log in (root directory '#' in this case).     
    #  target = "s3://${aws_s3_bucket.sftp_bucket.bucket}/ygt/terraform"            #The actual location in the S3 bucket that the user will be mapped to. In this case, it points to the path s3://<bucket-name>/ygt/terraform.
   #}
  #]
}

# Output the server's endpoint for easy reference
output "sftp_server_endpoint" {
  value       = aws_transfer_server.sftp_server.endpoint
  description = "SFTP Server VPC Endpoint for access"
}
