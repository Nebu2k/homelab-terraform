# ===========================================
# Canonical host redirects
# ===========================================
#
# One Single Redirect per zone, 301 from the non-canonical hostname to the
# canonical one. Both hostnames have to exist as custom domains on the Worker,
# otherwise the losing one never reaches Cloudflare and the rule cannot fire.
#
# preserve_query_string stays false on purpose: the wildcard match already
# carries the query string in ${1}, the flag would append it a second time.

locals {
  canonical_host = {
    for domain, site in var.sites :
    domain => site.canonical == "www" ? "www.${domain}" : domain
  }

  redirected_host = {
    for domain, site in var.sites :
    domain => site.canonical == "www" ? domain : "www.${domain}"
  }

  # apex -> www has to name the host; a generic "https://www.*" would match its
  # own target and loop.
  # $${1} escapes the HCL interpolation; Cloudflare gets a literal ${1}.
  match_pattern = {
    for domain, site in var.sites :
    domain => site.canonical == "apex" ? "https://www.*" : "https://${domain}/*"
  }

  replace_pattern = {
    for domain, site in var.sites :
    domain => site.canonical == "apex" ? "https://$${1}" : "https://www.${domain}/$${1}"
  }
}

resource "cloudflare_ruleset" "canonical_redirect" {
  for_each = var.sites

  zone_id = each.value.zone_id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    expression = "(http.request.full_uri wildcard r\"${local.match_pattern[each.key]}\")"
    action     = "redirect"
    enabled    = true

    action_parameters {
      from_value {
        status_code = 301
        target_url {
          expression = "wildcard_replace(http.request.full_uri, r\"${local.match_pattern[each.key]}\", r\"${local.replace_pattern[each.key]}\")"
        }
        preserve_query_string = false
      }
    }
  }
}
