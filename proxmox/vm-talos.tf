# Talos-Control-Plane-VM auf dem Proxmox-Host.
#
# Der Stack umfasst genau eine VM. Die beiden anderen Control-Plane-Nodes des
# Clusters laufen auf Blech und stehen deshalb nicht hier.
#
# Die VMs laufen bewusst nicht ueber ein Modul mit cloud-init: Talos hat keine
# Shell, keinen Paketmanager und keine User-Accounts. Die vollstaendige
# Node-Konfiguration steht als Machine Config unter kubernetes-homelab/talos/
# und wird per talosctl appliziert.

locals {
  # Adressen aus dem Cluster-Block .20-.29 des Adressplans. Der VIP (.248) und
  # der MetalLB-Pool (.240-.247) stehen nicht hier, die verwalten Talos selbst
  # bzw. MetalLB im Cluster.
  talos_nodes = {
    # usb_devices: Vendor/Product-IDs, die dieser VM durchgereicht werden.
    #
    # talos-cp-1 traegt den RTL-SDR (0bda:2838, RTL2838 DVB-T). readsb laeuft
    # als Pod im Cluster und ist per nodeSelector an genau diese Node gebunden;
    # ein Umstecken aendert diese Zeile und den nodeSelector in
    # kubernetes-homelab/manifests/readsb/deployment.yaml.
    #
    # Die Bindung laeuft ueber Vendor/Product, nicht ueber den Portpfad: so
    # findet qemu den Stick nach einem Reset auch an einem anderen Port wieder.
    #
    # ACHTUNG: das Hinzufuegen oder Entfernen eines usb-Blocks stoppt und startet
    # die VM. Nur bei gesundem etcd und nur an einer Node auf einmal.
    "talos-cp-1" = { vm_id = 110, ip = "192.168.2.20", usb_devices = ["0bda:2838"] }
  }
}

# Talos-Image aus der Image Factory. Die Schematic-ID kodiert die System
# Extensions (iscsi-tools und util-linux-tools fuer Longhorn, qemu-guest-agent
# fuer Proxmox) und muss zu der passen, die in
# kubernetes-homelab/talos/talconfig.yaml bei DIESER VM steht. Laufen sie
# auseinander, faellt die Node beim naechsten Upgrade auf ein Image ohne
# Extensions zurueck und Longhorn verliert seine Volumes.
#
# Die Blech-Nodes haben eigene Schematics ohne qemu-guest-agent, die stehen
# drueben. Diese Variable gilt ausschliesslich fuer die VM.
#
# nocloud statt metal: das Image ist ein fertiges Disk-Image und wird direkt als
# Boot-Disk geklont, die VM bootet sofort in den Maintenance-Mode.
resource "proxmox_download_file" "talos_nocloud_image" {
  content_type            = "iso"
  datastore_id            = var.talos_image_storage
  node_name               = var.proxmox_node
  url                     = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/nocloud-amd64.raw.zst"
  file_name               = "talos-${var.talos_version}-nocloud-amd64.img"
  decompression_algorithm = "zst"

  overwrite           = false
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_nodes

  name        = each.key
  description = "Talos Control Plane (${each.value.ip}), Konfiguration in kubernetes-homelab/talos/"
  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id
  tags        = ["talos", "kubernetes", "terraform"]

  on_boot = true
  started = true

  machine = "q35"
  bios    = "seabios"

  cpu {
    cores = var.talos_vm_cpu_cores
    # "host" statt kvm64: Talos setzt x86-64-v2 voraus, kvm64 erfuellt das nicht
    # und die VM bleibt beim Boot stehen.
    type = "host"
  }

  memory {
    dedicated = var.talos_vm_memory
  }

  disk {
    datastore_id = var.talos_vm_storage
    interface    = "scsi0"
    size         = var.talos_vm_disk_size
    file_format  = "raw"
    discard      = "on"
    ssd          = true
    file_id      = proxmox_download_file.talos_nocloud_image.id
  }

  network_device {
    bridge = var.talos_vm_network_bridge
  }

  # Leer fuer Nodes ohne durchgereichte Hardware, siehe usb_devices oben.
  dynamic "usb" {
    for_each = each.value.usb_devices
    content {
      host = usb.value
      usb3 = false
    }
  }

  operating_system {
    type = "l26"
  }

  # Der qemu-guest-agent kommt als System Extension aus dem Image und laeuft erst
  # nach dem Bootstrap. Proxmox kann die Node damit geordnet herunterfahren.
  #
  # Wird eine Node im Maintenance-Mode neu aufgesetzt, muss das vorher auf false:
  # ein aktivierter Agent laesst Terraform sonst auf eine IP warten, die in
  # diesem Zustand nie gemeldet wird.
  agent {
    enabled = true
    timeout = "1m"
  }

  lifecycle {
    ignore_changes = [
      started,
      # Talos-Upgrades laufen ueber "talosctl upgrade", nicht ueber ein frisch
      # geklontes Disk-Image. Ohne dieses Ignore wuerde eine neue talos_version
      # die VM samt EPHEMERAL-Partition neu bauen, also etcd und
      # Longhorn-Replikate mitnehmen.
      disk[0].file_id,
    ]
  }
}

output "talos_nodes" {
  description = "Talos-Control-Plane-VMs: Name, VM-ID und statische IP"
  value = {
    for name, node in local.talos_nodes : name => {
      vm_id = proxmox_virtual_environment_vm.talos[name].vm_id
      ip    = node.ip
    }
  }
}
