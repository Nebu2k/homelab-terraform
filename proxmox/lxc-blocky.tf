# Zweite Blocky-Instanz als LXC auf dem Proxmox-Host.
#
# Die erste laeuft im Cluster (kubernetes-homelab/manifests/blocky/). Die beiden
# decken einander komplementaer ab: stirbt pve, laufen raspi5 und prodesk weiter
# und damit die Cluster-Instanz. Hakt das Cluster, lebt diese hier. Ein Resolver
# an nur einer der beiden Stellen waere ein Single Point of Failure fuers ganze
# Haus.
#
# LXC und keine VM: Blocky ist ein statisches Go-Binary und Unbound ein
# Alpine-Paket. Eine VM waere fuer beides Verschwendung.
#
# WICHTIG bei der statischen ULA: vmbr0 braucht "bridge-mcsnoop 0". MLD-Snooping
# ohne Querier laesst statische IPv6-Adressen in Containern nach Minuten
# verschwinden.

locals {
  blocky_lxc = {
    vm_id = 402
    # Nachbaradresse der Cluster-Instanz (.253, MetalLB). Zusammenhaengend, damit
    # beide Resolver im UniFi-DHCP nebeneinander stehen. Die .254 liegt
    # ausserhalb des MetalLB-Pools (.240-.253), es gibt also keine Kollision.
    ipv4_address = "192.168.2.254/24"
    ipv4_gateway = "192.168.2.1"
    # Ohne v6-Pool in MetalLB kann die Cluster-Instanz keine v6-Adresse
    # anbieten. Das v6-DNS-Feld in UniFi haengt damit allein an dieser Instanz.
    # Die Adresse gehoert zusaetzlich in die UniFi-IP-Liste "HomeLab IPv6
    # Adguard", sonst faellt v6-DNS fuer die Gast-VLANs still aus.
    ipv6_address = "fd2e:9a71:c3b5::254/64"
  }

  blocky_snippets_dir = "/var/lib/vz/snippets"
}

# Das Alpine-Template. Terraform laedt es selbst herunter, statt ein von Hand
# per "pveam download" geholtes zu benutzen: sonst steht die Version nirgends im
# Code und ein frischer Host hat sie nicht.
resource "proxmox_download_file" "alpine_lxc_template" {
  content_type        = "vztmpl"
  datastore_id        = var.blocky_lxc_template_storage
  node_name           = var.proxmox_node
  url                 = "http://download.proxmox.com/images/system/${var.blocky_lxc_template}"
  file_name           = var.blocky_lxc_template
  overwrite           = false
  overwrite_unmanaged = true
}

# Die Blocky-Konfiguration selbst steht bewusst NICHT hier. Sie liegt im
# Cluster-Repo (manifests/blocky/config.yml) und der Container holt sie sich im
# Viertelstundentakt selbst, siehe blocky_config_sync weiter unten. Terraform
# besitzt den Container, nicht seinen Inhalt.
#
# Wuerde Terraform sie zusaetzlich hineinschieben, haette dieselbe Datei zwei
# Eigentuemer: ein apply mit nicht committeten Aenderungen wuerde etwas
# ausrollen, das der Sync eine Viertelstunde spaeter wieder zurueckdreht.

resource "proxmox_virtual_environment_file" "blocky_unbound_config" {
  content_type = "snippets"
  datastore_id = var.blocky_lxc_template_storage
  node_name    = var.proxmox_node

  source_raw {
    data      = file("${path.module}/blocky/unbound.conf")
    file_name = "blocky-unbound.conf"
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

# Holt config.yml im Viertelstundentakt selbst aus dem Cluster-Repo. Damit ist
# ein "terraform apply" nur noch fuer den Container noetig, nicht mehr fuer
# seine Konfiguration: ein Commit reicht, und beide Instanzen folgen. Die drei
# Sicherungen gegen einen gleichzeitigen Ausfall beider Resolver stehen im Kopf
# des Skripts.
#
# Die URL zeigt bewusst auf main und nicht auf einen Tag: ArgoCD zieht fuer die
# Cluster-Instanz denselben Branch. Zwei verschiedene Staende waeren genau das
# Auseinanderlaufen, das hier verhindert werden soll.
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
  description = "Blocky + Unbound (${split("/", local.blocky_lxc.ipv4_address)[0]}), Konfiguration in kubernetes-homelab/manifests/blocky/"
  tags        = ["blocky", "dns", "terraform"]

  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 2
  }

  memory {
    # Der Speicher haengt an den Blocklisten: HaGeZi Pro sind rund 215k
    # Eintraege. Mit Unbound-Cache daneben ist 1 GB die Groesse, bei der noch
    # Luft fuer eine groessere Liste bleibt.
    dedicated = 1024
    swap      = 512
  }

  disk {
    # local-lvm und nicht nvme-2tb: dort liegen nur worker-1 und vm-arch, und
    # der Container braucht keine 8 GB schnellen Speicher.
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
        # Kein Gateway noetig: der Container nimmt die Router Advertisements
        # von vmbr0 an und holt sich Default-Route, ISP-GUA und die
        # SLAAC-Adressen der ULA von selbst dazu. Diese statische Adresse
        # kommt oben drauf und existiert nur, damit im UniFi-DNS-Feld etwas
        # steht, das der rotierende ISP-Praefix nicht wegreisst.
        address = local.blocky_lxc.ipv6_address
      }
    }

    # Der Resolver des Containers selbst zeigt auf das UniFi-Gateway, nicht auf
    # sich selbst und nicht auf AdGuard. Auf sich selbst waere ein Henne-Ei bei
    # jedem Kaltstart (apk braucht DNS, bevor Blocky laeuft), auf AdGuard eine
    # Abhaengigkeit von genau dem Dienst, den diese Instanz abloest.
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
      # Ein manuelles Stoppen soll ein apply ueberleben, sonst startet
      # Terraform den Container mitten in einer Fehlersuche wieder.
      started,
    ]
  }
}

# Installiert Blocky und Unbound im Container und haelt beide auf Stand.
#
# Ein Provisioner und kein Hook-Script: der Hook liefe bei jedem Start des
# Containers und damit auch dann, wenn niemand etwas geaendert hat. Hier haengt
# der Lauf an den Pruefsummen der drei Dateien und der Blocky-Version, laeuft
# also genau dann, wenn es etwas zu tun gibt.
#
# Der Weg fuehrt ueber den Proxmox-Host und "pct", nicht per SSH in den
# Container: der hat keinen sshd, und einen nur fuer die Provisionierung
# einzurichten waere mehr Angriffsflaeche als Nutzen.
resource "terraform_data" "blocky_provision" {
  triggers_replace = {
    container      = proxmox_virtual_environment_container.blocky.id
    blocky_version = var.blocky_version
    unbound_config = sha256(file("${path.module}/blocky/unbound.conf"))
    openrc         = sha256(file("${path.module}/blocky/blocky.openrc"))
    config_sync    = sha256(file("${path.module}/blocky/config-sync.sh.tftpl"))
    node_exporter  = sha256(file("${path.module}/blocky/node-exporter.confd"))
    install_script = sha256(file("${path.module}/blocky/install.sh.tftpl"))
  }

  depends_on = [
    proxmox_virtual_environment_file.blocky_unbound_config,
    proxmox_virtual_environment_file.blocky_openrc,
    proxmox_virtual_environment_file.blocky_config_sync,
    proxmox_virtual_environment_file.blocky_node_exporter_confd,
    proxmox_virtual_environment_file.blocky_install_script,
  ]

  # Schluessel ausdruecklich, nicht ueber den Agent: der ist auf diesem Rechner
  # leer, die Anmeldung an pve laeuft ueber IdentityFile in ~/.ssh/config. Die
  # liest Terraform nicht, ein "agent = true" laeuft deshalb in
  # "no supported methods remain".
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
  description = "Blocky-LXC: Container-ID und statische Adressen"
  value = {
    vm_id = proxmox_virtual_environment_container.blocky.vm_id
    ipv4  = split("/", local.blocky_lxc.ipv4_address)[0]
    ipv6  = split("/", local.blocky_lxc.ipv6_address)[0]
  }
}
