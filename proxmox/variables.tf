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
# Werte stehen als default hier und nicht in terraform.tfvars: die tfvars ist
# gitignored und waere fuer jeden anderen Klon des Repos leer.

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
  # Der Wert deckt den Ausfall einer der beiden Blech-Control-Planes ab: die
  # beweglichen Pods von dort muessen auf die verbleibenden Nodes passen. Der
  # groesste davon ist Prometheus, und der traegt einen arch-Selektor auf amd64
  # (kubernetes-homelab, values.yaml der kube-prometheus-stack). Die arm64-Node
  # kann ihn nicht nehmen, diese VM ist damit sein einziger Ausweichplatz.
  #
  # Der Host hat 30 GB und traegt sonst keine VM mehr.
  #
  # Eine Aenderung kostet einen Stopp der VM: Proxmox haengt Speicher ohne
  # Ballooning nicht heiss an. Bei mehreren VMs nacheinander, nie gleichzeitig,
  # sonst faellt das etcd-Quorum. Diese Node traegt zudem den SDR, readsb und
  # fr24 sind waehrend des Reboots offline.
  default = 16384
}

variable "talos_vm_disk_size" {
  description = "Disk size in GB per Talos control plane VM (holds etcd and Longhorn replicas)"
  type        = number
  # Longhorn schedult nur, solange 25 Prozent der Disk frei bleiben
  # (storage-minimal-available-percentage), und ueberbucht nicht
  # (over-provisioning 100). Nutzbar sind davon also rund drei Viertel.
  #
  # Talos zieht die EPHEMERAL-Partition beim naechsten Boot selbst nach, ein
  # Resize wird erst mit einem Reboot wirksam.
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
# Blocky LXC (zweite Resolver-Instanz)
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
