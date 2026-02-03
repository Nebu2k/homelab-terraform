terraform {
  backend "s3" {
    bucket  = "homelab-elmstreet79-terraform-state"
    key     = "homelab/proxmox/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
