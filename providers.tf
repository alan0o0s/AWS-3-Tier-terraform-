provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Used by the compute module to generate an SSH keypair
provider "tls" {}

provider "random" {}
