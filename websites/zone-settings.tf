# ===========================================
# Zone settings
# ===========================================
#
# Only the settings named here are managed; everything else in the zone stays
# untouched. Read the current state before adding one, a value that lands here
# by accident is applied silently.
#
# `ssl` is deliberately NOT in this list. Two zones are on "flexible" and three
# on "full", and the mode only matters once a proxied record points at a real
# origin. For a worker there is no origin fetch at all. Changing it blind can
# take a site down with a 526, so it needs the record list first.

resource "cloudflare_zone_settings_override" "site" {
  for_each = var.sites

  zone_id = each.value.zone_id

  settings {
    # Already on everywhere, pinned so it stays that way.
    always_use_https         = "on"
    automatic_https_rewrites = "on"
    tls_1_3                  = "on"

    # haushelden-service.de and homeworx.solutions were still on 1.0.
    min_tls_version = "1.2"

    security_header {
      enabled = true
      # One year. Shorter defeats the purpose, browsers ignore very small
      # values for preload eligibility anyway.
      max_age            = 31536000
      include_subdomains = each.value.hsts_subdomains
      nosniff            = true
      # Deliberately off, and it should stay off unless there is a reason.
      # Preloading is a one-way street: getting back out of the browser lists
      # takes an application and months.
      preload = false
    }
  }
}
