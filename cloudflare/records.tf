# ===========================================
# Public DNS Records
# ===========================================
#
# One CNAME per public host -> DynDNS target (nebu2k.ipv64.net), which tracks the
# home public IP. The single UniFi 80/443 port-forward sends traffic to Traefik
# (192.168.2.250), which routes by Host header and terminates TLS with the
# Let's Encrypt wildcard cert. A CNAME inherits both A and AAAA of the target,
# so public access is v4 + v6 automatically.
#
# DNS-only (proxied = false): TLS is terminated at Traefik, not Cloudflare.

resource "cloudflare_record" "public" {
  for_each = var.public_hosts

  zone_id = var.cloudflare_zone_id
  name    = each.value
  content = var.dyndns_target
  type    = "CNAME"
  ttl     = 300
  proxied = false
  comment = "managed-by: terraform (public exposure)"
}

# Apex (nackte Domain). Cloudflare flacht den CNAME am Zone-Root automatisch auf
# A/AAAA ab (CNAME-Flattening) und lässt ihn mit den MX/TXT-Records koexistieren,
# stört die iCloud-Mail also nicht. Traefik leitet Host `elmstreet79.de` per
# 301 auf www weiter (manifests/landing-page/apex-redirect.yaml).
resource "cloudflare_record" "apex" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  content = var.dyndns_target
  type    = "CNAME"
  ttl     = 300
  proxied = false
  comment = "managed-by: terraform (apex -> www)"
}
