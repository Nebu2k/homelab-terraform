# Arch Linux VM

module "vm_arch" {
  source = "./vm-module"

  # Proxmox Configuration (from root variables)
  proxmox_node    = var.proxmox_node
  snippet_storage = var.snippet_storage
  ssh_public_key  = var.ssh_public_key

  # VM Identity
  vm_name        = "vm-arch"
  vm_id          = 103
  vm_description = "Arch Linux VM with cloud-init configuration"
  vm_on_boot     = false

  # Cloud Image
  image_url           = "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
  image_file_name     = "Arch-Linux-x86_64-cloudimg.img"
  cloud_init_template = "arch"
  cloud_init_user     = "arch"

  # Keep original cloud-init filename to avoid recreation
  cloud_init_filename = "arch-cloud-init.yaml"

  # Resources
  vm_cpu_cores = 2
  vm_memory    = 2048
  vm_disk_size = 100
  vm_disk_ssd  = true

  # Storage
  vm_storage         = "nvme-2tb"
  cloud_init_storage = "nvme-2tb"

  # Network
  vm_network_bridge = "vmbr0"
  vm_network_tag    = 0
  vm_ip_address     = "192.168.2.13/24"
  vm_gateway        = "192.168.2.1"
  vm_dns_servers    = ["192.168.2.4", "192.168.2.16"]
}

# Outputs specific to Arch Linux VM
output "arch_vm_id" {
  description = "Arch Linux VM ID"
  value       = module.vm_arch.vm_id
}

output "arch_vm_ip" {
  description = "Arch Linux VM IP address"
  value       = module.vm_arch.vm_ip
}

output "arch_ssh_command" {
  description = "SSH connection command"
  value       = module.vm_arch.ssh_command
}

output "arch_connection_info" {
  description = "Arch Linux connection information"
  value       = <<-EOT

  Arch Linux VM deployed successfully!

  SSH Access:
    ${module.vm_arch.ssh_command}

  EOT
}
