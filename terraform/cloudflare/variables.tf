# ===========================================
# Provider Credentials
# ===========================================

variable "cloudflare_api_token" {
  description = "Cloudflare API Token (Zone:DNS:Edit + Zone:Read)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for elmstreet79.de"
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

# Publicly exposed services. Each becomes a CNAME <name>.elmstreet79.de -> dyndns_target.
# Everything NOT listed here has no public record and is reachable internally/VPN only
# (split-horizon wildcard rewrite *.elmstreet79.de -> Traefik 192.168.2.250).
variable "public_hosts" {
  description = "Subdomains exposed to the internet via the single 80/443 port-forward"
  type        = set(string)
  default = [
    "www",
    "dreambox",
    "homeassistant",
    "plex",
    "teslamate",
  ]
}
