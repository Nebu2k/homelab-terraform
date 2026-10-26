# Adopts the existing objects after the move to provider v5, which has no state
# upgrade path for them. Delete after the first successful apply.

import {
  to = cloudflare_dns_record.public["homeassistant"]
  id = "ee6597dea58f18ca57987dd261e736f4/046202d271d13cd013c78b74f784e3cc"
}

import {
  to = cloudflare_dns_record.public["plex"]
  id = "ee6597dea58f18ca57987dd261e736f4/ee101defbbc3a8c6188a356402aa08fa"
}
