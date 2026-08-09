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

# ============================================
# Talos Control Plane VMs
# ============================================
# Defaults statt tfvars-Eintraege: terraform.tfvars ist gitignored, ein Wert nur
# dort waere fuer jeden anderen Klon des Repos verschwunden.

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
  # Am 2026-08-09 von 4096 auf 8192 erhoeht, nach dem Abschalten des
  # k3s-Clusters: dessen beide VMs gaben 12 GB frei, und drei Talos-Nodes
  # tragen jetzt, was vorher fuenf trugen. talos-cp-2 lag bei 90 Prozent
  # Speicherbelegung, KubeMemoryOvercommit stand dauerhaft an.
  #
  # BEWUSST VORLAEUFIG: sobald raspi5 als Control-Plane joint und talos-cp-2
  # ersetzt, bleibt hier nur noch eine VM uebrig und der Wert gehoert neu
  # gerechnet. pve hat 30 GB gesamt.
  #
  # Eine Aenderung kostet je VM einen Stopp: Proxmox haengt Speicher ohne
  # Ballooning nicht heiss an. Nacheinander, nie beide gleichzeitig, sonst
  # faellt das etcd-Quorum.
  default = 8192
}

variable "talos_vm_disk_size" {
  description = "Disk size in GB per Talos control plane VM (holds etcd and Longhorn replicas)"
  type        = number
  # Am 2026-08-09 von 128 auf 400 erhoeht, vor der zweiten Migrationswelle.
  #
  # Longhorn schedult nur, solange 25 Prozent der Disk frei bleiben
  # (storage-minimal-available-percentage), und ueberbucht nichts
  # (over-provisioning 100). Aus 128 GB wurden damit 93 GiB nutzbar je VM, also
  # 363 GiB im Cluster gegen 326 GiB Bedarf bei Replica 2. Zu wenig, sobald
  # Snapshots dazukommen.
  #
  # Die Disks liegen auf nvme-2tb, das reichlich frei hat. Der Engpass auf pve
  # ist der RAM, nicht die Platte: deshalb groessere Disks statt einer weiteren
  # Worker-VM. Die kommt, wenn das k3s-Cluster seine 12 GB freigibt.
  #
  # Talos zieht die EPHEMERAL-Partition beim naechsten Boot selbst nach, ein
  # Resize wird also erst mit einem Reboot wirksam.
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
