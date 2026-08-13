# ===========================================
# Provider Credentials
# ===========================================

# Needs more reach than the token in cloudflare/, which only sees
# elmstreet79.de. Required grants are listed in README.md.
variable "cloudflare_api_token" {
  description = "Cloudflare API Token covering every zone in var.sites"
  type        = string
  sensitive   = true
}

# ===========================================
# Sites
# ===========================================

# One entry per website. `canonical` decides which of the two hostnames wins;
# the other one gets a 301 to it. The sites themselves are deployed by
# Cloudflare's own build integration from their GitHub repo, which Terraform
# cannot express: there is no resource for the repo-to-Worker connection, and
# the script upload of a static-assets Worker belongs to wrangler. What lives
# here is the wiring around it.
variable "sites" {
  description = "Websites by domain, with the hostname that should win"
  type = map(object({
    zone_id   = string
    canonical = string # "apex" or "www"

    # HSTS with includeSubDomains. The header is sent for the website, but the
    # browser applies it to every subdomain of the zone, so a zone that carries
    # more than the website has to opt out: one service that speaks plain HTTP
    # would become unreachable, and stay so for the max-age even after the
    # setting is taken back.
    hsts_subdomains = optional(bool, true)
  }))

  validation {
    condition     = alltrue([for s in var.sites : contains(["apex", "www"], s.canonical)])
    error_message = "canonical must be either \"apex\" or \"www\"."
  }
}
