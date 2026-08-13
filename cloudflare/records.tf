# ===========================================
# Public DNS Records
# ===========================================
#
# One CNAME per public host -> the DynDNS target, which tracks the home public
# IP. A single 80/443 port-forward sends traffic to Traefik, which routes by
# Host header and terminates TLS with a Let's Encrypt wildcard certificate. A
# CNAME inherits both A and AAAA of its target, so public access is v4 and v6.
#
# DNS-only (proxied = false): TLS is terminated at Traefik, not at Cloudflare.

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

# The apex and www are custom domains on the elmstreet79-de Worker, so
# Cloudflare owns those records and there is no resource for them here.
#
# The mail records (MX, TXT, DKIM) of this zone live in the websites stack,
# next to those of the other four domains, because they are the same setup.
