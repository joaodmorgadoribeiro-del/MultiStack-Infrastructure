terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ─────────────────────────────────────────────
# S3 Bucket – Remote State Storage
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "terraform_state" {
  bucket = "project-1-joao-irene-tfstate"

  # Prevent accidental deletion of the state bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "project-1-joao-irene-tfstate"
    Project = "project-1-joao-irene"
    Purpose = "Terraform remote state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────
# DynamoDB Table – State Locking
# ─────────────────────────────────────────────

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "project-1-joao-irene-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "project-1-joao-irene-tflock"
    Project = "project-1-joao-irene"
    Purpose = "Terraform state locking"
  }
}

# ─────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking."
  value       = aws_dynamodb_table.terraform_lock.name
}
