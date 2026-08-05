terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

# Credentials kommen aus der AWS-CLI-Umgebung (~/.aws, Profil "default"), genau
# wie beim S3-State-Backend aller drei Stacks. Deshalb gibt es hier keine
# terraform.tfvars und keine Variable fuer Key/Secret.
provider "aws" {
  region = var.aws_region
}
