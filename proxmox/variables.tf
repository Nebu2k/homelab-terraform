# ============================================
# Proxmox Provider Configuration
# ============================================

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox API username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox host"
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
}

# ============================================
# Global VM Defaults (passed to vm-module)
# ============================================

variable "snippet_storage" {
  description = "Storage pool for cloud-init snippets (must support snippets, e.g., 'local')"
  type        = string
  default     = "local"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

# ============================================
# Application-Specific Variables
# ============================================

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  default     = "minio-admin"
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "pbs_root_password" {
  description = "Proxmox Backup Server root@pam password (for web interface)"
  type        = string
  sensitive   = true
}
