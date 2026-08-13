# ===========================================
# Provider Credentials
# ===========================================

variable "cloudflare_api_token" {
  description = "Cloudflare API Token (Zone:DNS:Edit + Zone:Read)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID of the managed zone"
  type        = string
}

# ===========================================
# DNS
# ===========================================

variable "domain" {
  description = "Base domain"
  type        = string
  default     = "elmstreet79.de"
}

variable "dyndns_target" {
  description = "DynDNS hostname the public CNAMEs point at (tracks the home public IP)"
  type        = string
  default     = "nebu2k.ipv64.net"
}

# Publicly exposed services. Each becomes a CNAME <name>.<domain> -> dyndns_target.
# Anything not listed here has no public record and resolves only internally,
# through the split-horizon wildcard rewrite that points *.<domain> at Traefik.
#
# `www` and the apex are NOT in here: they are custom domains on the
# elmstreet79-de Worker, and Cloudflare owns those records. A record of ours on
# the same name makes the Worker deploy fail, wrangler refuses to overwrite one
# it did not create.
variable "public_hosts" {
  description = "Subdomains exposed to the internet via the single 80/443 port-forward"
  type        = set(string)
  default = [
    "homeassistant",
    "plex",
  ]
}
