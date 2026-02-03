# ===========================================
# Cloudflare DNS Records
# ===========================================

# Main Pangolin domain
resource "cloudflare_record" "pangolin" {
  zone_id = var.cloudflare_zone_id
  name    = "pangolin"
  content = hcloud_server.pangolin.ipv4_address
  type    = "A"
  ttl     = 300
  proxied = false
}

# Pangolin API domain (Integration API)
resource "cloudflare_record" "pangolin_api" {
  zone_id = var.cloudflare_zone_id
  name    = "pangolin-api"
  content = hcloud_server.pangolin.ipv4_address
  type    = "A"
  ttl     = 300
  proxied = false
}

# IPv6 records
resource "cloudflare_record" "pangolin_ipv6" {
  zone_id = var.cloudflare_zone_id
  name    = "pangolin"
  content = hcloud_server.pangolin.ipv6_address
  type    = "AAAA"
  ttl     = 300
  proxied = false
}

resource "cloudflare_record" "pangolin_api_ipv6" {
  zone_id = var.cloudflare_zone_id
  name    = "pangolin-api"
  content = hcloud_server.pangolin.ipv6_address
  type    = "AAAA"
  ttl     = 300
  proxied = false
}
