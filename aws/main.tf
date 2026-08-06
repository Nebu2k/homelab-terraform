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

  # Legt man in der Konsole einen Access Key an, fragt AWS nach einer
  # "Description". Die landet nicht am Key, sondern als TAG AM IAM-USER, und
  # zwar mit der Key-ID als Tag-Namen (belegt am 2026-08-05 an
  # homelab-teslamate-backup, Tag "AKIA...").
  #
  # Da Terraform die User-Tags verwaltet, sieht es diesen Fremdkoerper als Drift
  # und wuerde ihn beim naechsten apply wieder loeschen. Damit waere die einzige
  # Stelle weg, an der steht, wofuer ein Key eigentlich da ist.
  #
  # ignore_tags mit key_prefixes statt einer Aufzaehlung in ignore_changes: die
  # Tag-Namen sind Key-IDs, die sich bei jeder Rotation aendern. Ein Prefix
  # ueberlebt das, eine hartkodierte Liste nicht.
  ignore_tags {
    key_prefixes = ["AKIA"]
  }
}
