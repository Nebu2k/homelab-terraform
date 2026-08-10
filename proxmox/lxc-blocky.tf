# Second Blocky instance as an LXC on the Proxmox host.
#
# The first one runs in the cluster (kubernetes-homelab/manifests/blocky/).
# The two cover each other complementarily: if pve dies, raspi5 and prodesk
# keep running and with them the cluster instance. If the cluster stalls, this
# one lives. A resolver in only one of the two places would be a single point
# of failure for the whole house.
#
# LXC and not a VM: Blocky is a static Go binary and Unbound an Alpine
# package. A VM would be wasteful for both.
#
# IMPORTANT for the static ULA: vmbr0 needs "bridge-mcsnoop 0". MLD snooping
# without a querier makes static IPv6 addresses in containers disappear after
# minutes.

locals {
  blocky_lxc = {
    vm_id = 402
    # Neighbouring address of the cluster instance (.253, MetalLB). Adjacent so
    # both resolvers sit next to each other in the UniFi DHCP settings. The
    # .254 is outside the MetalLB pool (.240-.253), so there is no collision.
    ipv4_address = "192.168.2.254/24"
    ipv4_gateway = "192.168.2.1"
    # Without a v6 pool in MetalLB the cluster instance cannot offer a v6
    # address. The v6 DNS field in UniFi therefore hangs off this instance
    # alone. The address additionally belongs in the UniFi IP list "HomeLab
    # IPv6 Adguard", otherwise v6 DNS fails silently for the guest VLANs.
    ipv6_address = "fd2e:9a71:c3b5::254/64"
  }

  blocky_snippets_dir = "/var/lib/vz/snippets"
}

# The Alpine template. Terraform downloads it itself rather than using one
# fetched by hand via "pveam download": otherwise the version is nowhere in
# the code and a fresh host does not have it.
resource "proxmox_download_file" "alpine_lxc_template" {
  content_type        = "vztmpl"
  datastore_id        = var.blocky_lxc_template_storage
  node_name           = var.proxmox_node
  url                 = "http://download.proxmox.com/images/system/${var.blocky_lxc_template}"
  file_name           = var.blocky_lxc_template
  overwrite           = false
  overwrite_unmanaged = true
}

# The Blocky configuration itself deliberately does NOT live here. It sits in
# the cluster repo (manifests/blocky/config.yml) and the container fetches it
# every quarter of an hour on its own, see blocky_config_sync further down.
# Terraform owns the container, not its content.
#
# If Terraform pushed it in as well, the same file would have two owners: an
# apply with uncommitted changes would roll out something the sync reverts a
# quarter of an hour later.

resource "proxmox_virtual_environment_file" "blocky_unbound_config" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data      = file("${path.module}/blocky/unbound.conf")
    file_name = "blocky-unbound.conf"
  }
}

resource "proxmox_virtual_environment_file" "blocky_unbound_confd" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data      = file("${path.module}/blocky/unbound.confd")
    file_name = "blocky-unbound.confd"
  }
}

resource "proxmox_virtual_environment_file" "blocky_openrc" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data      = file("${path.module}/blocky/blocky.openrc")
    file_name = "blocky-openrc.sh"
  }
}

# Fetches config.yml from the cluster repo every quarter of an hour on its
# own. That makes a "terraform apply" necessary only for the container, no
# longer for its configuration: a commit is enough and both instances follow.
# The three safeguards against both resolvers failing at once are in the head
# of the script.
#
# The URL deliberately points at main and not at a tag: ArgoCD pulls the same
# branch for the cluster instance. Two different states would be exactly the
# drift this is meant to prevent.
resource "proxmox_virtual_environment_file" "blocky_config_sync" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/blocky/config-sync.sh.tftpl", {
      config_url   = var.blocky_config_url
      textfile_dir = "/var/lib/node_exporter/textfile"
    })
    file_name = "blocky-config-sync.sh"
  }
}

resource "proxmox_virtual_environment_file" "blocky_node_exporter_confd" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data      = file("${path.module}/blocky/node-exporter.confd")
    file_name = "blocky-node-exporter.confd"
  }
}

resource "proxmox_virtual_environment_file" "blocky_install_script" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/blocky/install.sh.tftpl", {
      vmid           = local.blocky_lxc.vm_id
      blocky_version = var.blocky_version
      snippets_dir   = local.blocky_snippets_dir
    })
    file_name = "blocky-install.sh"
  }
}

resource "proxmox_virtual_environment_container" "blocky" {
  node_name   = var.proxmox_node
  vm_id       = local.blocky_lxc.vm_id
  description = "Blocky + Unbound (${split("/", local.blocky_lxc.ipv4_address)[0]}), configuration in kubernetes-homelab/manifests/blocky/"
  tags        = ["blocky", "dns", "terraform"]

  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 2
  }

  memory {
    # Memory hangs off the blocklists: HaGeZi Pro is around 215k entries. With
    # the Unbound cache next to it, 1 GB is the size that leaves room for a
    # larger list.
    dedicated = 1024
    swap      = 512
  }

  disk {
    # local-lvm and not nvme-2tb: only worker-1 and vm-arch live there, and the
    # container does not need 8 GB of fast storage.
    datastore_id = "local-lvm"
    size         = 8
  }

  operating_system {
    template_file_id = proxmox_download_file.alpine_lxc_template.id
    type             = "alpine"
  }

  initialization {
    hostname = "blocky"

    ip_config {
      ipv4 {
        address = local.blocky_lxc.ipv4_address
        gateway = local.blocky_lxc.ipv4_gateway
      }
      ipv6 {
        # No gateway needed: the container accepts the router advertisements
        # from vmbr0 and picks up the default route, the ISP GUA and the SLAAC
        # addresses of the ULA by itself. This static address comes on top and
        # exists only so the UniFi DNS field holds something the rotating ISP
        # prefix cannot tear away.
        address = local.blocky_lxc.ipv6_address
      }
    }

    # The container's own resolver points at the UniFi gateway, not at itself
    # and not at AdGuard. At itself would be a chicken and egg on every cold
    # start (apk needs DNS before Blocky runs), at AdGuard a dependency on
    # exactly the service this instance replaces.
    dns {
      servers = [local.blocky_lxc.ipv4_gateway]
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.talos_vm_network_bridge
  }

  lifecycle {
    ignore_changes = [
      # Stopping it by hand should survive an apply, otherwise Terraform
      # starts the container again in the middle of a debugging session.
      started,
    ]
  }
}

# Installs Blocky and Unbound in the container and keeps both current.
#
# A provisioner and not a hook script: the hook would run on every start of
# the container and therefore also when nobody changed anything. Here the run
# hangs off the checksums of the files and the Blocky version, so it runs
# exactly when there is something to do.
#
# The path leads through the Proxmox host and "pct", not via SSH into the
# container: it has no sshd, and setting one up just for provisioning would be
# more attack surface than benefit.
resource "terraform_data" "blocky_provision" {
  triggers_replace = {
    container      = proxmox_virtual_environment_container.blocky.id
    blocky_version = var.blocky_version
    unbound_config = sha256(file("${path.module}/blocky/unbound.conf"))
    unbound_confd  = sha256(file("${path.module}/blocky/unbound.confd"))
    openrc         = sha256(file("${path.module}/blocky/blocky.openrc"))
    config_sync    = sha256(file("${path.module}/blocky/config-sync.sh.tftpl"))
    node_exporter  = sha256(file("${path.module}/blocky/node-exporter.confd"))
    install_script = sha256(file("${path.module}/blocky/install.sh.tftpl"))
  }

  depends_on = [
    proxmox_virtual_environment_file.blocky_unbound_config,
    proxmox_virtual_environment_file.blocky_unbound_confd,
    proxmox_virtual_environment_file.blocky_openrc,
    proxmox_virtual_environment_file.blocky_config_sync,
    proxmox_virtual_environment_file.blocky_node_exporter_confd,
    proxmox_virtual_environment_file.blocky_install_script,
  ]

  # Key explicitly, not through the agent: it is empty on this machine, the
  # login to pve runs through IdentityFile in ~/.ssh/config. Terraform does not
  # read that, so an "agent = true" ends up in "no supported methods remain".
  connection {
    type        = "ssh"
    host        = regex("^https?://([^:/]+)", var.proxmox_endpoint)[0]
    user        = var.proxmox_ssh_username
    private_key = file(pathexpand(var.proxmox_ssh_private_key))
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "sh ${local.blocky_snippets_dir}/blocky-install.sh",
    ]
  }
}

output "blocky_lxc" {
  description = "Blocky LXC: container id and static addresses"
  value = {
    vm_id = proxmox_virtual_environment_container.blocky.vm_id
    ipv4  = split("/", local.blocky_lxc.ipv4_address)[0]
    ipv6  = split("/", local.blocky_lxc.ipv6_address)[0]
  }
}
