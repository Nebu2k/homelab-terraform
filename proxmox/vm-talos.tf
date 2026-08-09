# Talos-Control-Plane-VMs (Cluster-Neubau)
#
# Gestartet als drei VMs, die das neue Talos-Cluster parallel zum bestehenden
# k3s-Cluster bootstrappen. Drei statt zwei, weil "talosctl upgrade" die Node
# rebootet: mit einem einzelnen etcd-Member haengt jedes Upgrade am verlorenen
# Quorum.
#
# Seit dem 2026-08-09 sind es zwei. prodesk ist als Blech-Control-Plane (.23)
# dazugekommen, damit waren es kurzzeitig vier etcd-Member. Eine gerade Anzahl
# vertraegt nicht mehr Ausfaelle als drei, also ist talos-cp-3 (.22, vmid 112)
# geloescht worden: erst drain, dann "talosctl reset --graceful", das laesst die
# Node geordnet aus etcd austreten. Spaeter ersetzt raspi5 eine weitere.
#
# Bewusst NICHT ueber ./vm-module: das Modul ist auf cloud-init zugeschnitten
# (User, Pakete, runcmd, snippets). Talos hat davon nichts, es gibt keine Shell
# und keinen Paketmanager. Die gesamte Node-Konfiguration steht in der machine
# config unter kubernetes-homelab/talos/ und wird per talosctl appliziert.

locals {
  # Adressen aus dem Cluster-Block .20-.29 des Adressplans. Der VIP (.248) und
  # der MetalLB-Pool des neuen Clusters (.240-.247) stehen NICHT hier, die
  # verwaltet Talos selbst bzw. MetalLB im Cluster.
  talos_nodes = {
    # usb_devices: Vendor/Product-IDs, die dieser VM durchgereicht werden.
    #
    # talos-cp-1 traegt den RTL-SDR (0bda:2838, RTL2838 DVB-T). Der Stick steckt
    # seit dem 2026-08-08 an pve statt an raspi5, readsb laeuft als Pod im
    # Cluster und ist per nodeSelector an genau diese Node gebunden.
    #
    # Bindung ueber Vendor/Product und nicht ueber den Portpfad: es ist nur ein
    # Stick im Spiel, und qemu findet ihn so nach einem Reset von selbst wieder.
    # Ein Portpfad waere nach dem naechsten Umstecken falsch.
    #
    # Diese Node ist damit ein Pet. Sie ist deshalb die, die den Abbau der
    # Start-VMs ueberlebt: geloescht wurde talos-cp-3, nicht diese. Wandert der
    # Stick doch woanders hin, aendert sich hier die Zeile und in
    # kubernetes-homelab/manifests/readsb/deployment.yaml der nodeSelector.
    #
    # ACHTUNG: das Hinzufuegen oder Entfernen eines usb-Blocks stoppt und
    # startet die VM. Nur bei gesundem etcd und nur an einer Node auf einmal.
    "talos-cp-1" = { vm_id = 110, ip = "192.168.2.20", usb_devices = ["0bda:2838"] }
    "talos-cp-2" = { vm_id = 111, ip = "192.168.2.21", usb_devices = [] }
  }
}

# Talos-Image aus der Image Factory. Die Schematic-ID kodiert die System
# Extensions (iscsi-tools und util-linux-tools fuer Longhorn, qemu-guest-agent
# fuer Proxmox) und muss zu der passen, die in
# kubernetes-homelab/talos/talconfig.yaml bei DIESEN VMs steht, sonst faellt die
# Node beim naechsten Upgrade auf ein Image ohne Extensions zurueck und Longhorn
# verliert seine Volumes.
#
# prodesk hat seit dem 2026-08-09 eine eigene Schematic ohne qemu-guest-agent,
# die steht nur drueben. Diese Variable gilt ausschliesslich fuer die VMs.
#
# nocloud statt metal: das Image ist ein fertiges Disk-Image und wird direkt als
# Boot-Disk geklont. Damit entfaellt der Umweg ueber eine ISO plus
# Installationslauf, die VM bootet sofort in den Maintenance-Mode.
resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
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
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  }

  network_device {
    bridge = var.talos_vm_network_bridge
  }

  # Leer fuer die Nodes ohne Hardware, siehe usb_devices in locals oben.
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

  # Beim ersten Apply stand das auf false: im Maintenance-Mode laeuft der
  # qemu-guest-agent noch nicht und ein aktivierter Agent laesst Terraform auf
  # eine IP warten, die nie gemeldet wird. Seit dem Bootstrap laeuft die
  # Extension, Proxmox kann die Nodes damit geordnet herunterfahren.
  #
  # Falls eine Node je wieder im Maintenance-Mode neu aufgesetzt wird: vorher
  # zurueck auf false, sonst haengt der naechste Apply.
  agent {
    enabled = true
    timeout = "1m"
  }

  lifecycle {
    ignore_changes = [
      started,
      # Talos-Upgrades laufen ueber "talosctl upgrade", nicht ueber ein frisch
      # geklontes Disk-Image. Ohne das Ignore wuerde eine neue talos_version die
      # VM samt EPHEMERAL-Partition neu bauen, also etcd und Longhorn-Replikate
      # mitnehmen.
      disk[0].file_id,
    ]
  }
}

output "talos_nodes" {
  description = "Talos-Control-Plane-VMs: Name, VM-ID und geplante statische IP"
  value = {
    for name, node in local.talos_nodes : name => {
      vm_id = proxmox_virtual_environment_vm.talos[name].vm_id
      ip    = node.ip
    }
  }
}
