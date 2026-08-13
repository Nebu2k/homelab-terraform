# ===========================================
# Canonical host redirects
# ===========================================
#
# One Single Redirect per zone, 301 from the non-canonical hostname to the
# canonical one, path and query string preserved. Both hostnames have to exist
# as custom domains on the Worker, otherwise the losing one never reaches
# Cloudflare and the rule cannot fire.

locals {
  # The hostname that wins, and the one that gets redirected to it.
  canonical_host = {
    for domain, site in var.sites :
    domain => site.canonical == "www" ? "www.${domain}" : domain
  }

  redirected_host = {
    for domain, site in var.sites :
    domain => site.canonical == "www" ? domain : "www.${domain}"
  }
}

resource "cloudflare_ruleset" "canonical_redirect" {
  for_each = var.sites

  zone_id = each.value.zone_id
  name    = "Canonical host redirect"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    ref         = "canonical_host"
    description = "301 ${local.redirected_host[each.key]} to ${local.canonical_host[each.key]}"
    expression  = "(http.host eq \"${local.redirected_host[each.key]}\")"
    action      = "redirect"
    enabled     = true

    action_parameters {
      from_value {
        status_code = 301
        target_url {
          expression = "concat(\"https://${local.canonical_host[each.key]}\", http.request.uri.path)"
        }
        preserve_query_string = true
      }
    }
  }
}
