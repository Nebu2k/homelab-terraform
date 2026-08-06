# # Windows 11 VM (ID 104)
# # Verwendet SATA + e1000 → Windows-Setup läuft ohne Treiberbeigabe.
# # VirtIO-Treiber/QEMU-Agent erst NACH Installation per virtio-win.iso nachziehen
# # (https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso).

# variable "windows_iso" {
#   description = "Dateiname der Windows-ISO im ISO-Storage"
#   type        = string
#   default     = "Win11_25H2_EnglishInternational_x64_v2.iso"
# }

# variable "windows_iso_storage" {
#   description = "Storage, in dem die Windows-ISO liegt"
#   type        = string
#   default     = "local"
# }

# resource "proxmox_virtual_environment_vm" "vm_windows" {
#   name        = "vm-windows"
#   description = "Windows 11 VM"
#   node_name   = var.proxmox_node
#   vm_id       = 104

#   on_boot = false
#   started = true

#   machine = "q35"
#   bios    = "ovmf"

#   cpu {
#     cores = 8
#     type  = "host"
#   }

#   memory {
#     dedicated = 8192
#   }

#   # EFI-Disk (Pflicht bei OVMF)
#   efi_disk {
#     datastore_id      = "longhorn-storage"
#     file_format       = "raw"
#     type              = "4m"
#     pre_enrolled_keys = true
#   }

#   # TPM v2.0 (Pflicht bei Win11)
#   tpm_state {
#     datastore_id = "longhorn-storage"
#     version      = "v2.0"
#   }

#   # System-Disk (SATA → keine Treiber im Setup nötig)
#   disk {
#     datastore_id = "longhorn-storage"
#     interface    = "sata0"
#     size         = 100
#     file_format  = "raw"
#     discard      = "on"
#     ssd          = true
#   }

#   # Windows-Installations-ISO
#   cdrom {
#     file_id   = "${var.windows_iso_storage}:iso/${var.windows_iso}"
#     interface = "ide2"
#   }

#   # e1000 → nativer Windows-Treiber, kein VirtIO im Setup nötig
#   network_device {
#     bridge  = "vmbr0"
#     model   = "e1000"
#     vlan_id = null
#   }

#   operating_system {
#     type = "win11"
#   }

#   boot_order = ["ide2", "sata0"]

#   vga {
#     type = "std"
#   }

#   agent {
#     enabled = true
#     timeout = "5m"
#   }

#   lifecycle {
#     ignore_changes = [
#       started,
#       cdrom,
#     ]
#   }
# }

# output "windows_vm_id" {
#   description = "Windows VM ID"
#   value       = proxmox_virtual_environment_vm.vm_windows.vm_id
# }

# output "windows_connection_info" {
#   description = "Hinweise zur Windows-VM"
#   value       = <<-EOT

#   Windows VM (ID 104) erstellt — SATA + e1000 (Setup ohne VirtIO).

#   Schritte nach dem Apply:
#     1. Proxmox-Web-UI → Konsole → Windows installieren (Disk wird sofort erkannt).
#     2. Optional nach Installation: virtio-win.iso anhängen und virtio-win-guest-tools.exe
#        ausführen → QEMU-Agent + bessere Treiber. Dann ggf. NIC auf virtio umstellen.
#     3. Kryptex installieren, CPU-Mining starten.

#   EOT
# }
