# ===========================================
# Pangolin Variables
# ===========================================

variable "pangolin_domain" {
  description = "Main domain for Pangolin"
  type        = string
  default     = "pangolin.elmstreet79.de"
}

variable "pangolin_api_domain" {
  description = "API domain for Pangolin Integration API"
  type        = string
  default     = "pangolin-api.elmstreet79.de"
}

variable "pangolin_server_secret" {
  description = "Pangolin server secret (from config.yml)"
  type        = string
  sensitive   = true
}

variable "smtp_from" {
  description = "SMTP from address"
  type        = string
  default     = "pangolin@elmstreet79.de"
}

variable "maxmind_license_key" {
  description = "MaxMind License Key for GeoLite2 database download"
  type        = string
  sensitive   = true
}

# ===========================================
# Locals
# ===========================================

locals {
  pangolin_subdomain     = split(".", var.pangolin_domain)[0]
  pangolin_api_subdomain = split(".", var.pangolin_api_domain)[0]
}

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

  user_data = templatefile("${path.module}/files/pangolin/cloud-init.yaml.tftpl", {
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
    docker_compose         = file("${path.module}/files/pangolin/docker-compose.yml")
    config_yml = templatefile("${path.module}/files/pangolin/config.yml.tftpl", {
      pangolin_domain        = var.pangolin_domain
      pangolin_server_secret = var.pangolin_server_secret
      smtp_host              = var.smtp_host
      smtp_port              = var.smtp_port
      smtp_user              = var.smtp_user
      smtp_pass              = var.smtp_pass
      smtp_from              = var.smtp_from
    })
    traefik_config_yml = templatefile("${path.module}/files/pangolin/traefik_config.yml.tftpl", {
      letsencrypt_email = var.letsencrypt_email
    })
    dynamic_config_yml = templatefile("${path.module}/files/pangolin/dynamic_config.yml.tftpl", {
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

# ===========================================
# DNS Records
# ===========================================

# Main Pangolin domain
resource "cloudflare_record" "pangolin" {
  zone_id = var.cloudflare_zone_id
  name    = local.pangolin_subdomain
  content = hcloud_server.pangolin.ipv4_address
  type    = "A"
  ttl     = 1
  proxied = false
}

# Pangolin API domain (Integration API)
resource "cloudflare_record" "pangolin_api" {
  zone_id = var.cloudflare_zone_id
  name    = local.pangolin_api_subdomain
  content = hcloud_server.pangolin.ipv4_address
  type    = "A"
  ttl     = 1
  proxied = false
}

# IPv6 records
resource "cloudflare_record" "pangolin_ipv6" {
  zone_id = var.cloudflare_zone_id
  name    = local.pangolin_subdomain
  content = hcloud_server.pangolin.ipv6_address
  type    = "AAAA"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "pangolin_api_ipv6" {
  zone_id = var.cloudflare_zone_id
  name    = local.pangolin_api_subdomain
  content = hcloud_server.pangolin.ipv6_address
  type    = "AAAA"
  ttl     = 1
  proxied = false
}

# ===========================================
# Outputs
# ===========================================

output "server_ipv4" {
  description = "Public IPv4 address of the Pangolin server"
  value       = hcloud_server.pangolin.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address of the Pangolin server"
  value       = hcloud_server.pangolin.ipv6_address
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.pangolin.id
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh pangolin@${hcloud_server.pangolin.ipv4_address}"
}

output "pangolin_url" {
  description = "Pangolin Dashboard URL"
  value       = "https://${var.pangolin_domain}"
}

output "pangolin_api_url" {
  description = "Pangolin Integration API URL"
  value       = "https://${var.pangolin_api_domain}/v1/docs"
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    pangolin     = "${var.pangolin_domain} -> ${hcloud_server.pangolin.ipv4_address}"
    pangolin_api = "${var.pangolin_api_domain} -> ${hcloud_server.pangolin.ipv4_address}"
  }
}

output "get_setup_token" {
  description = "Run this command to get the Pangolin setup token"
  value       = "ssh pangolin@${hcloud_server.pangolin.ipv4_address} 'docker logs pangolin 2>&1 | grep Token:'"
}
