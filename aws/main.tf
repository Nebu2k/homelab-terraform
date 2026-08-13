terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

# Credentials come from the AWS CLI environment (~/.aws, profile "default"),
# same as the S3 state backend of every stack. There is no terraform.tfvars
# here and no variable for key/secret.
provider "aws" {
  region = var.aws_region

  # The "description" AWS asks for when creating an access key in the console
  # ends up as a tag on the IAM user, with the key id as the tag name.
  # Terraform manages the user tags and would otherwise remove them as drift.
  # The tag names change on every rotation, hence a prefix rather than a list.
  ignore_tags {
    key_prefixes = ["AKIA"]
  }
}

# SES sits in Ireland, everything else in Frankfurt. The region is part of the
# MAIL FROM MX record, so moving it would mean a DNS change on a working
# sender.
provider "aws" {
  alias  = "ireland"
  region = var.ses_region

  ignore_tags {
    key_prefixes = ["AKIA"]
  }
}
