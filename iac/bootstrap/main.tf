terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.35.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


locals {
  prefix = "${var.app}-${var.env}"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state-bucket" {
  bucket = "${local.prefix}-${data.aws_caller_identity.current.account_id}-tfstate"

  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name        = "${local.prefix}-tfstate"
    Environment = var.env
    ManagedBy   = "tfstate_bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "state-bucket" {
  bucket = aws_s3_bucket.state-bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state-bucket" {
  bucket = aws_s3_bucket.state-bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state-bucket" {
  bucket = aws_s3_bucket.state-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate-lock" {
  name         = "${local.prefix}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${local.prefix}-tfstate-lock"
    Environment = var.env
    ManagedBy   = "tfstate_bootstrap"
  }
}