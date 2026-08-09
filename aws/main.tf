terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

# Credentials kommen aus der AWS-CLI-Umgebung (~/.aws, Profil "default"), wie
# beim S3-State-Backend aller Stacks. Es gibt hier keine terraform.tfvars und
# keine Variable fuer Key/Secret.
provider "aws" {
  region = var.aws_region

  # Die "Description", die AWS beim Anlegen eines Access Keys in der Konsole
  # abfragt, landet als Tag am IAM-User, mit der Key-ID als Tag-Namen. Terraform
  # verwaltet die User-Tags und wuerde sie sonst als Drift entfernen. Die
  # Tag-Namen aendern sich bei jeder Rotation, deshalb ein Prefix statt einer
  # Aufzaehlung.
  ignore_tags {
    key_prefixes = ["AKIA"]
  }
}
