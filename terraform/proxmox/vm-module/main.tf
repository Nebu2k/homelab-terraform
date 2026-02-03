# Download Ubuntu Cloud Image (shared across all VMs using this module)
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.ubuntu_image_storage
  node_name    = var.proxmox_node
  url          = var.ubuntu_image_url

  overwrite           = false
  overwrite_unmanaged = true
}

# Create VM
resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.vm_description
  node_name   = var.proxmox_node
  vm_id       = var.vm_id

  on_boot = var.vm_on_boot
  started = true

  machine = "q35"

  cpu {
    cores = var.vm_cpu_cores
    type  = var.vm_cpu_type
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.vm_storage
    interface    = "scsi0"
    size         = var.vm_disk_size
    file_format  = "raw"
    discard      = "on"
    ssd          = var.vm_disk_ssd
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  }

  network_device {
    bridge  = var.vm_network_bridge
    vlan_id = var.vm_network_tag != 0 ? var.vm_network_tag : null
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
    timeout = "1m"
  }

  # Network and DNS configuration via cloud-init
  initialization {
    datastore_id      = var.cloud_init_storage
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
    
    ip_config {
      ipv4 {
        address = var.vm_ip_address
        gateway = var.vm_gateway
      }
    }
    
    dns {
      servers = var.vm_dns_servers
    }
  }

  lifecycle {
    ignore_changes = [
      started,
    ]
  }
}

# Cloud-init user data (users, packages, runcmd)
resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = var.snippet_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      vm_name                = var.vm_name
      cloud_init_user        = var.cloud_init_user
      ssh_public_key         = var.ssh_public_key
      dns_server_1           = length(var.vm_dns_servers) > 0 ? var.vm_dns_servers[0] : "1.1.1.1"
      dns_server_2           = length(var.vm_dns_servers) > 1 ? var.vm_dns_servers[1] : "8.8.8.8"
      cloud_init_packages    = var.cloud_init_packages
      cloud_init_runcmd      = var.cloud_init_runcmd
      vm_ip_address          = var.vm_ip_address
      vm_gateway             = var.vm_gateway
    })

    file_name = var.cloud_init_filename != "" ? var.cloud_init_filename : "${var.vm_name}-cloud-init.yaml"
  }
}

