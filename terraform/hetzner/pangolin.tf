# ===========================================
# Firewall
# ===========================================

resource "hcloud_firewall" "pangolin" {
  name = "pangolin-firewall"

  # SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # HTTP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # WireGuard
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # WireGuard (secondary)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "21820"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP (ping)
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# ===========================================
# Server
# ===========================================

resource "hcloud_server" "pangolin" {
  name        = "pangolin"
  image       = var.server_image
  server_type = var.server_type
  location    = var.location

  ssh_keys = [hcloud_ssh_key.homelab.id]

  firewall_ids = [hcloud_firewall.pangolin.id]

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    ssh_public_key         = var.ssh_public_key
    pangolin_domain        = var.pangolin_domain
    pangolin_api_domain    = var.pangolin_api_domain
    pangolin_server_secret = var.pangolin_server_secret
    smtp_host              = var.smtp_host
    smtp_port              = var.smtp_port
    smtp_user              = var.smtp_user
    smtp_pass              = var.smtp_pass
    smtp_from              = var.smtp_from
    maxmind_license_key    = var.maxmind_license_key
    letsencrypt_email      = var.letsencrypt_email
    docker_compose         = file("${path.module}/files/docker-compose.yml")
    config_yml = templatefile("${path.module}/files/config.yml.tftpl", {
      pangolin_domain        = var.pangolin_domain
      pangolin_server_secret = var.pangolin_server_secret
      smtp_host              = var.smtp_host
      smtp_port              = var.smtp_port
      smtp_user              = var.smtp_user
      smtp_pass              = var.smtp_pass
      smtp_from              = var.smtp_from
    })
    traefik_config_yml = templatefile("${path.module}/files/traefik_config.yml.tftpl", {
      letsencrypt_email = var.letsencrypt_email
    })
    dynamic_config_yml = templatefile("${path.module}/files/dynamic_config.yml.tftpl", {
      pangolin_domain     = var.pangolin_domain
      pangolin_api_domain = var.pangolin_api_domain
    })
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    environment = "production"
    service     = "pangolin"
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}
