# Proxmox Configuration (passed from root)
variable "proxmox_node" {
  description = "Proxmox node name where VM will be created"
  type        = string
}

variable "snippet_storage" {
  description = "Storage pool for cloud-init snippets (must support snippets)"
  type        = string
  default     = "local"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

# VM Base Configuration
variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID (must be unique)"
  type        = number
}

variable "vm_description" {
  description = "VM description"
  type        = string
  default     = "Managed by Terraform"
}

variable "vm_on_boot" {
  description = "Start VM on Proxmox boot"
  type        = bool
  default     = true
}

# CPU & Memory
variable "vm_cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

# Disk Configuration
variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "vm_disk_ssd" {
  description = "Enable SSD emulation"
  type        = bool
  default     = true
}

variable "vm_storage" {
  description = "Storage pool for VM disk"
  type        = string
  default     = "longhorn-storage"
}

variable "cloud_init_storage" {
  description = "Storage pool for cloud-init disk"
  type        = string
  default     = "longhorn-storage"
}

# Network Configuration
variable "vm_network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_network_tag" {
  description = "VLAN tag (0 for no VLAN)"
  type        = number
  default     = 0
}

variable "vm_ip_address" {
  description = "Static IP address (CIDR notation, e.g., 192.168.2.100/24)"
  type        = string
}

variable "vm_gateway" {
  description = "Default gateway"
  type        = string
  default     = "192.168.2.1"
}

variable "vm_dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.2.4", "192.168.2.16"]
}

# Cloud-init Customization
variable "cloud_init_user" {
  description = "Cloud-init default username"
  type        = string
  default     = "ubuntu"
}

variable "cloud_init_packages" {
  description = "Additional packages to install via cloud-init (qemu-guest-agent is always installed)"
  type        = list(string)
  default     = []
}

variable "cloud_init_runcmd" {
  description = "Additional commands to run via cloud-init"
  type        = list(string)
  default     = []
}

variable "cloud_init_write_files" {
  description = "Files to write via cloud-init"
  type = list(object({
    path        = string
    content     = string
    permissions = optional(string, "0644")
  }))
  default = []
}

# Ubuntu Cloud Image
variable "ubuntu_image_url" {
  description = "Ubuntu cloud image URL"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "ubuntu_image_storage" {
  description = "Storage for Ubuntu cloud image"
  type        = string
  default     = "local"
}

variable "cloud_init_filename" {
  description = "Custom filename for cloud-init file (optional, defaults to vm_name-cloud-init.yaml)"
  type        = string
  default     = ""
}
