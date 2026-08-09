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
  # Am 2026-08-09 in zwei Schritten von 4096 ueber 8192 auf 16384. Der zweite
  # Schritt ist die angekuendigte Neuberechnung: seit dem Abbau von talos-cp-2
  # gilt diese Variable nur noch fuer EINE VM, talos-cp-1.
  #
  # Der Wert ist nicht "was frei war", sondern der gemessene Ausfallfall. Faellt
  # prodesk aus, muessen 6034 Mi umziehen (nur die beweglichen Pods, ohne
  # DaemonSets und statische Control-Plane-Pods). Frei waren bei 8192 MB:
  # raspi5 4396 Mi, talos-cp-1 3332 Mi, zusammen 7728 Mi. Es passte, aber ohne
  # Reserve.
  #
  # Entscheidend ist dabei nicht die Summe, sondern ein arch-Pin: Prometheus
  # ist mit 1290 Mi der groesste bewegliche Pod und traegt
  # kubernetes.io/arch: amd64 (begruendet in kubernetes-homelab, values.yaml
  # der kube-prometheus-stack). raspi5 ist arm64 und kann ihn NICHT nehmen,
  # egal wie viel dort frei ist. talos-cp-1 ist damit der einzige
  # Ausweichplatz fuer den groessten Brocken, und deshalb bekommt genau er den
  # Speicher.
  #
  # pve hat 30 GB gesamt und ausser dieser VM laeuft dort nichts mehr, es
  # bleiben also rund 14 GB fuer den Host.
  #
  # Eine Aenderung kostet einen Stopp der VM: Proxmox haengt Speicher ohne
  # Ballooning nicht heiss an. Bei mehreren VMs nacheinander, nie gleichzeitig,
  # sonst faellt das etcd-Quorum. Und talos-cp-1 traegt den SDR: readsb und
  # fr24 sind waehrend des Reboots offline, was FR24 verkraftet.
  default = 16384
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
