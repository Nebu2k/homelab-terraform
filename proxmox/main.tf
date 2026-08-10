terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # Lower bound 0.111.1: older versions do not know the
      # proxmox_download_file resource type yet.
      version = ">= 0.111.1, < 1.0.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_insecure

  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
