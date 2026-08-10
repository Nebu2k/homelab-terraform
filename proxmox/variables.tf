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

variable "proxmox_ssh_private_key" {
  description = "Path to the SSH private key used to reach the Proxmox host (the provisioner cannot read ~/.ssh/config)"
  type        = string
  default     = "~/.ssh/homelab"
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
}

# ============================================
# Talos Control Plane VMs
# ============================================
# Values sit here as defaults rather than in terraform.tfvars: the tfvars is
# gitignored and would be empty for any other clone of the repo.

variable "talos_version" {
  description = "Talos version for the Image Factory download (must match kubernetes-homelab/talos/talconfig.yaml)"
  type        = string
  default     = "v1.13.8"
}

variable "talos_schematic_id" {
  description = "Image Factory schematic ID: iscsi-tools, util-linux-tools, qemu-guest-agent"
  type        = string
  default     = "88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b"
}

variable "talos_vm_cpu_cores" {
  description = "CPU cores per Talos control plane VM"
  type        = number
  default     = 4
}

variable "talos_vm_memory" {
  description = "Memory in MB per Talos control plane VM"
  type        = number
  # The value covers the loss of one of the two bare-metal control planes: the
  # movable pods from there have to fit on the remaining nodes. The largest of
  # them is Prometheus, and it carries an arch selector on amd64
  # (kubernetes-homelab, values.yaml of the kube-prometheus-stack). The arm64
  # node cannot take it, which makes this VM its only fallback spot.
  #
  # The host has 30 GB and carries no other VM.
  #
  # A change costs a stop of the VM: Proxmox does not attach memory hot without
  # ballooning. With several VMs one after another, never at the same time, or
  # etcd loses quorum. This node also carries the SDR, so readsb and fr24 are
  # offline during the reboot.
  default = 16384
}

variable "talos_vm_disk_size" {
  description = "Disk size in GB per Talos control plane VM (holds etcd and Longhorn replicas)"
  type        = number
  # Longhorn only schedules while 25 percent of the disk stays free
  # (storage-minimal-available-percentage) and does not overcommit
  # (over-provisioning 100). Roughly three quarters of this is usable.
  #
  # Talos grows the EPHEMERAL partition itself on the next boot, so a resize
  # only takes effect with a reboot.
  default = 400
}

variable "talos_vm_storage" {
  description = "Storage pool for Talos VM disks"
  type        = string
  default     = "nvme-2tb"
}

variable "talos_image_storage" {
  description = "Storage pool for the downloaded Talos image"
  type        = string
  default     = "local"
}

variable "talos_vm_network_bridge" {
  description = "Network bridge for Talos VMs"
  type        = string
  default     = "vmbr0"
}

# ============================================
# Blocky LXC (second resolver instance)
# ============================================

variable "blocky_version" {
  description = "Blocky release tag for the LXC instance (must match the image tag in kubernetes-homelab/manifests/blocky/deployment.yaml)"
  type        = string
  # renovate: datasource=github-releases depName=0xERR0R/blocky
  default = "v0.34.0"
}

variable "blocky_config_url" {
  description = "Raw URL of the shared Blocky config; the LXC pulls it every 15 minutes so a commit is enough to reach both instances"
  type        = string
  default     = "https://raw.githubusercontent.com/Nebu2k/kubernetes-homelab/main/manifests/blocky/config.yml"
}

variable "blocky_lxc_template" {
  description = "Proxmox LXC template file name for the Blocky container"
  type        = string
  default     = "alpine-3.24-default_20260714_amd64.tar.xz"
}

variable "blocky_lxc_template_storage" {
  description = "Storage pool holding the LXC template and the config snippets (needs content types vztmpl and snippets)"
  type        = string
  default     = "local"
}
