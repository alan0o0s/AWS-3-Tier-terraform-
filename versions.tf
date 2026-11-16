terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote state backend (recommended for real/production use).
  #
  # Terraform does not allow interpolation in the backend block, so the bucket,
  # key, region, and lock table must be hardcoded or passed via -backend-config
  # at `terraform init` time. See README.md "Remote State Backend" section for
  # the bootstrap process (creating the S3 bucket + DynamoDB table first).
  #
  # Uncomment and fill in once the backend resources exist, then run:
  #   terraform init -migrate-state
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "company-web-platform-tfstate"
  #   key            = "aws-3tier-terraform/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "company-web-platform-tf-locks"
  #   encrypt        = true
  # }
}
