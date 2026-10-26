# ===========================================
# Zone settings
# ===========================================
#
# Only the settings named here are managed; everything else in the zone stays
# untouched. Read the current state before adding one, a value that lands here
# by accident is applied silently.

locals {
  zone_settings = {
    # Already on everywhere, pinned so it stays that way.
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    tls_1_3                  = "on"

    # A worker does no origin fetch, so this only bites once a proxied record
    # points at a real host. It is the guardrail for that day.
    ssl = "strict"

    min_tls_version = "1.2"
  }

  site_settings = {
    for pair in setproduct(keys(var.sites), keys(local.zone_settings)) :
    "${pair[0]}/${pair[1]}" => { domain = pair[0], setting_id = pair[1] }
  }
}

resource "cloudflare_zone_setting" "site" {
  for_each = local.site_settings

  zone_id    = var.sites[each.value.domain].zone_id
  setting_id = each.value.setting_id
  value      = local.zone_settings[each.value.setting_id]
}

# Its own resource because its value is an object, not a string.
resource "cloudflare_zone_setting" "hsts" {
  for_each = var.sites

  zone_id    = each.value.zone_id
  setting_id = "security_header"
  value = {
    strict_transport_security = {
      enabled            = true
      max_age            = 31536000
      include_subdomains = each.value.hsts_subdomains
      nosniff            = true
      # Deliberately off: preloading is a one-way street, getting back out of
      # the browser lists takes an application and months.
      preload = false
    }
  }
}
