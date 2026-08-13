terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# The DKIM tokens of elmstreet79.de belong to the SES identity in the aws
# stack, which therefore has to be applied first. Same bucket as the backend
# above, so the AWS credentials are already in the environment.
data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    bucket = "homelab-elmstreet79-terraform-state"
    key    = "homelab/aws/terraform.tfstate"
    region = "eu-central-1"
  }
}
