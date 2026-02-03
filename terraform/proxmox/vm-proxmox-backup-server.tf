# Proxmox Backup Server VM
# Backup storage for Proxmox VE VMs and containers

module "proxmox_backup_server" {
  source = "./vm-module"

  # Proxmox Configuration (from root variables)
  proxmox_node    = var.proxmox_node
  snippet_storage = var.snippet_storage
  ssh_public_key  = var.ssh_public_key

  # VM Identity
  vm_name        = "proxmox-backup-server"
  vm_id          = 501
  vm_description = "Proxmox Backup Server for VM/CT backups"

  # Resources
  vm_cpu_cores = 4
  vm_memory    = 4096
  vm_disk_size = 50
  vm_disk_ssd  = true

  # Storage
  vm_storage         = "longhorn-storage"
  cloud_init_storage = "longhorn-storage"

  # Network
  vm_network_bridge = "vmbr0"
  vm_network_tag    = 0
  vm_ip_address     = "192.168.2.14/24"
  vm_gateway        = "192.168.2.1"
  vm_dns_servers    = ["192.168.2.4", "192.168.2.16"]

  # Cloud-init customization
  cloud_init_packages = [
    "wget",
    "gnupg"
  ]

  cloud_init_runcmd = [
    # Set root password for PBS web interface (root@pam login)
    "echo 'root:${var.pbs_root_password}' | chpasswd",
    # Add Proxmox repository key and sources for PBS on Ubuntu
    "wget -qO /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg",
    "echo 'deb [arch=amd64] http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription' > /etc/apt/sources.list.d/pbs.list",
    "apt-get update",
    "DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-backup-server",
    "systemctl enable proxmox-backup-proxy proxmox-backup",
    "systemctl start proxmox-backup-proxy proxmox-backup"
  ]
}

# Outputs specific to Proxmox Backup Server
output "pbs_vm_id" {
  description = "Proxmox Backup Server VM ID"
  value       = module.proxmox_backup_server.vm_id
}

output "pbs_vm_ip" {
  description = "Proxmox Backup Server IP address"
  value       = module.proxmox_backup_server.vm_ip
}

output "pbs_ssh_command" {
  description = "SSH connection command"
  value       = module.proxmox_backup_server.ssh_command
}

output "pbs_web_interface" {
  description = "Proxmox Backup Server Web Interface"
  value       = "https://${module.proxmox_backup_server.vm_ip}:8007"
}

output "pbs_connection_info" {
  description = "Proxmox Backup Server connection information"
  value       = <<-EOT
  
  Proxmox Backup Server deployed successfully!
  
  SSH Access (ubuntu user, key-only):
    ${module.proxmox_backup_server.ssh_command}
  
  Web Interface:
    URL: https://${module.proxmox_backup_server.vm_ip}:8007
    User: root@pam
    Password: (set via TF_VAR_pbs_root_password)
    
  First Steps:
    1. Access web interface at https://${module.proxmox_backup_server.vm_ip}:8007
    2. Login with root@pam and your configured password
    3. Add external datastores (S3, NFS, etc.)
    4. Configure backup jobs in Proxmox VE
  EOT
}
