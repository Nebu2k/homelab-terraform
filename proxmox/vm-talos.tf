# Talos control plane VM on the Proxmox host.
#
# The stack covers exactly one VM. The cluster's other two control plane nodes
# run on bare metal and therefore are not here.
#
# The VMs deliberately do not go through a module with cloud-init: Talos has
# no shell, no package manager and no user accounts. The complete node
# configuration lives as a machine config under kubernetes-homelab/talos/ and
# is applied with talosctl.

locals {
  # Addresses from the .20-.29 cluster block of the address plan. The VIP
  # (.248) and the MetalLB pool (.240-.247) are not here, those are managed by
  # Talos itself and by MetalLB in the cluster.
  talos_nodes = {
    # usb_devices: vendor/product ids passed through to this VM.
    #
    # talos-cp-1 carries the RTL-SDR (0bda:2838, RTL2838 DVB-T). readsb runs as
    # a pod in the cluster and is bound to exactly this node by nodeSelector;
    # moving the stick changes this line and the nodeSelector in
    # kubernetes-homelab/manifests/readsb/deployment.yaml.
    #
    # The binding goes by vendor/product, not by port path: that way qemu finds
    # the stick again on a different port after a reset.
    #
    # CAUTION: adding or removing a usb block stops and starts the VM. Only
    # with healthy etcd and only on one node at a time.
    "talos-cp-1" = { vm_id = 110, ip = "192.168.2.20", usb_devices = ["0bda:2838"] }
  }
}

# Talos image from the Image Factory. The schematic id encodes the system
# extensions (iscsi-tools and util-linux-tools for Longhorn, qemu-guest-agent
# for Proxmox) and has to match the one kubernetes-homelab/talos/talconfig.yaml
# carries for THIS VM. If they drift apart, the node falls back to an image
# without extensions on the next upgrade and Longhorn loses its volumes.
#
# The bare-metal nodes have their own schematics without qemu-guest-agent,
# those live over there. This variable applies to the VM only.
#
# nocloud instead of metal: the image is a finished disk image and is cloned
# directly as the boot disk, so the VM boots straight into maintenance mode.
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
  description = "Talos control plane (${each.value.ip}), configuration in kubernetes-homelab/talos/"
  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id
  tags        = ["talos", "kubernetes", "terraform"]

  on_boot = true
  started = true

  machine = "q35"
  bios    = "seabios"

  cpu {
    cores = var.talos_vm_cpu_cores
    # "host" instead of kvm64: Talos requires x86-64-v2, kvm64 does not meet
    # that and the VM stalls at boot.
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

  # Empty for nodes without passed-through hardware, see usb_devices above.
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

  # The qemu-guest-agent comes from the image as a system extension and only
  # runs after the bootstrap. It lets Proxmox shut the node down in an orderly
  # way.
  #
  # When a node is rebuilt in maintenance mode this has to go to false first:
  # an enabled agent otherwise makes Terraform wait for an IP that is never
  # reported in that state.
  agent {
    enabled = true
    timeout = "1m"
  }

  lifecycle {
    ignore_changes = [
      started,
      # Talos upgrades run through "talosctl upgrade", not through a freshly
      # cloned disk image. Without this ignore, a new talos_version would
      # rebuild the VM including the EPHEMERAL partition, taking etcd and the
      # Longhorn replicas with it.
      disk[0].file_id,
    ]
  }
}

output "talos_nodes" {
  description = "Talos control plane VMs: name, vm id and static IP"
  value = {
    for name, node in local.talos_nodes : name => {
      vm_id = proxmox_virtual_environment_vm.talos[name].vm_id
      ip    = node.ip
    }
  }
}
