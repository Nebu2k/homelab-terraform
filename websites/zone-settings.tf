# ===========================================
# Zone settings
# ===========================================
#
# Only the settings named here are managed; everything else in the zone stays
# untouched. Read the current state before adding one, a value that lands here
# by accident is applied silently.

resource "cloudflare_zone_settings_override" "site" {
  for_each = var.sites

  zone_id = each.value.zone_id

  settings {
    # Already on everywhere, pinned so it stays that way.
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    tls_1_3                  = "on"

    # A worker does no origin fetch, so this only bites once a proxied record
    # points at a real host. It is the guardrail for that day.
    ssl = "strict"

    min_tls_version = "1.2"

    security_header {
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
