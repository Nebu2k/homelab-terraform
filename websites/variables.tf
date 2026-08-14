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
# the other one gets a 301 to it. Deploys are not in scope here: they run from
# each repo's GitHub Action, and there is no provider resource for a worker's
# repo connection anyway.
variable "sites" {
  description = "Websites by domain, with the hostname that should win"
  type = map(object({
    zone_id   = string
    canonical = string # "apex" or "www"

    # HSTS with includeSubDomains. Browsers apply it to every subdomain of the
    # zone, so a zone carrying more than the website has to opt out: a service
    # on plain HTTP would be unreachable, and stay so for the max-age.
    hsts_subdomains = optional(bool, true)

    # Whether the redirected hostname is a custom domain on the Worker as well.
    # Only then can the redirect skip a path and still be answered.
    both_hosts_on_worker = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for s in var.sites : contains(["apex", "www"], s.canonical)])
    error_message = "canonical must be either \"apex\" or \"www\"."
  }
}
