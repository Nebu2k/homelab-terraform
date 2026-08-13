# MX, SPF, DMARC and DKIM of every zone in var.sites, minus the records
# Email Routing owns on seb-it.com: the API rejects every write to those
# with error 1046.
#
# Three zones receive and send through iCloud and carry nothing else.
# seb-it.com receives through Email Routing, which cannot send, and
# elmstreet79.de sends from the Postfix on pve. Both of those send through SES
# from their own mail. subdomain.

locals {
  mail_records = {
    "elmstreet79.de/dkim-sig1-domainkey" = {
      zone_key = "elmstreet79.de"
      name     = "sig1._domainkey"
      type     = "CNAME"
      value    = "sig1.dkim.elmstreet79.de.at.icloudmailadmin.com"
      ttl      = 3600
      comment  = "iCloud Email"
    }
    "elmstreet79.de/mx-apex" = {
      zone_key = "elmstreet79.de"
      name     = "elmstreet79.de"
      type     = "MX"
      value    = "mx01.mail.icloud.com"
      ttl      = 3600
      priority = 10
      comment  = "iCloud Email"
    }
    "elmstreet79.de/mx-apex-2" = {
      zone_key = "elmstreet79.de"
      name     = "elmstreet79.de"
      type     = "MX"
      value    = "mx02.mail.icloud.com"
      ttl      = 3600
      priority = 10
      comment  = "iCloud Email"
    }
    "elmstreet79.de/dmarc-dmarc" = {
      zone_key = "elmstreet79.de"
      name     = "_dmarc"
      type     = "TXT"
      value    = "\"v=DMARC1; p=reject; rua=mailto:b0e120aa05694979ab0929a1f2519f8d@dmarc-reports.cloudflare.net\""
      ttl      = 1
    }
    "elmstreet79.de/apple" = {
      zone_key = "elmstreet79.de"
      name     = "elmstreet79.de"
      type     = "TXT"
      value    = "\"apple-domain=Am5ovavCqA97HOC1\""
      ttl      = 3600
      comment  = "iCloud Email"
    }
    "elmstreet79.de/spf" = {
      # No include:amazonses.com here: SES sends from mail.elmstreet79.de,
      # which carries its own record, and SPF checks the envelope sender.
      zone_key = "elmstreet79.de"
      name     = "elmstreet79.de"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
      comment  = "SPF"
    }
    # MAIL FROM of the SES identity, see homelab-terraform/aws/ses-mail.tf. The
    # MX has no recipient behind it, SES only wants it to exist for bounces.
    "elmstreet79.de/mx-mail" = {
      zone_key = "elmstreet79.de"
      name     = "mail"
      type     = "MX"
      value    = "feedback-smtp.eu-west-1.amazonses.com"
      ttl      = 1
      priority = 10
    }
    "elmstreet79.de/spf-mail" = {
      zone_key = "elmstreet79.de"
      name     = "mail"
      type     = "TXT"
      value    = "\"v=spf1 include:amazonses.com ~all\""
      ttl      = 1
    }
    "haushelden-service.de/dkim-sig1-domainkey" = {
      zone_key = "haushelden-service.de"
      name     = "sig1._domainkey"
      type     = "CNAME"
      value    = "sig1.dkim.haushelden-service.de.at.icloudmailadmin.com"
      ttl      = 3600
    }
    "haushelden-service.de/mx-apex" = {
      zone_key = "haushelden-service.de"
      name     = "haushelden-service.de"
      type     = "MX"
      value    = "mx01.mail.icloud.com"
      ttl      = 3600
      priority = 10
    }
    "haushelden-service.de/mx-apex-2" = {
      zone_key = "haushelden-service.de"
      name     = "haushelden-service.de"
      type     = "MX"
      value    = "mx02.mail.icloud.com"
      ttl      = 3600
      priority = 10
    }
    "haushelden-service.de/dmarc-dmarc" = {
      zone_key = "haushelden-service.de"
      name     = "_dmarc"
      type     = "TXT"
      value    = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=r; rua=mailto:f587ce0e3e884db390506893466f2e85@dmarc-reports.cloudflare.net\""
      ttl      = 1
    }
    "haushelden-service.de/apple" = {
      zone_key = "haushelden-service.de"
      name     = "haushelden-service.de"
      type     = "TXT"
      value    = "\"apple-domain=YItF3tz3QEkStemT\""
      ttl      = 3600
    }
    "haushelden-service.de/spf" = {
      zone_key = "haushelden-service.de"
      name     = "haushelden-service.de"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
    }
    "homeworx.solutions/dkim-sig1-domainkey" = {
      zone_key = "homeworx.solutions"
      name     = "sig1._domainkey"
      type     = "CNAME"
      value    = "sig1.dkim.homeworx.solutions.at.icloudmailadmin.com"
      ttl      = 3600
    }
    "homeworx.solutions/mx-apex" = {
      zone_key = "homeworx.solutions"
      name     = "homeworx.solutions"
      type     = "MX"
      value    = "mx01.mail.icloud.com"
      ttl      = 3600
      priority = 10
    }
    "homeworx.solutions/mx-apex-2" = {
      zone_key = "homeworx.solutions"
      name     = "homeworx.solutions"
      type     = "MX"
      value    = "mx02.mail.icloud.com"
      ttl      = 3600
      priority = 10
    }
    "homeworx.solutions/dmarc-dmarc" = {
      zone_key = "homeworx.solutions"
      name     = "_dmarc"
      type     = "TXT"
      value    = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=r; rua=mailto:b1a131acb9b04de18876c30c5d3887c4@dmarc-reports.cloudflare.net\""
      ttl      = 1
    }
    "homeworx.solutions/apple" = {
      zone_key = "homeworx.solutions"
      name     = "homeworx.solutions"
      type     = "TXT"
      value    = "\"apple-domain=CI3M3Anfs9tu7G10\""
      ttl      = 3600
    }
    "homeworx.solutions/spf" = {
      zone_key = "homeworx.solutions"
      name     = "homeworx.solutions"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
    }
    "peters.club/dkim-sig1-domainkey" = {
      zone_key = "peters.club"
      name     = "sig1._domainkey"
      type     = "CNAME"
      value    = "sig1.dkim.peters.club.at.icloudmailadmin.com"
      ttl      = 3600
    }
    "peters.club/mx-apex" = {
      zone_key = "peters.club"
      name     = "peters.club"
      type     = "MX"
      value    = "mx01.mail.icloud.com"
      ttl      = 3600
      priority = 10
    }
    "peters.club/mx-apex-2" = {
      zone_key = "peters.club"
      name     = "peters.club"
      type     = "MX"
      value    = "mx02.mail.icloud.com"
      ttl      = 3600
      priority = 10
    }
    "peters.club/dmarc-dmarc" = {
      zone_key = "peters.club"
      name     = "_dmarc"
      type     = "TXT"
      value    = "\"v=DMARC1; p=reject; rua=mailto:76f78c60a5ef4ef9a7c5e3844edfbb66@dmarc-reports.cloudflare.net\""
      ttl      = 1
    }
    "peters.club/apple" = {
      zone_key = "peters.club"
      name     = "peters.club"
      type     = "TXT"
      value    = "\"apple-domain=XS0m3FPUGpBkPZmn\""
      ttl      = 3600
    }
    "peters.club/spf" = {
      zone_key = "peters.club"
      name     = "peters.club"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
    }
    "seb-it.com/mx-mail" = {
      zone_key = "seb-it.com"
      name     = "mail"
      type     = "MX"
      value    = "feedback-smtp.eu-west-1.amazonses.com"
      ttl      = 1
      priority = 10
    }
    "seb-it.com/dmarc-dmarc" = {
      zone_key = "seb-it.com"
      name     = "_dmarc"
      type     = "TXT"
      value    = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=r; rua=mailto:b2665cefbafe42d2b469d69cfd1582bc@dmarc-reports.cloudflare.net;\""
      ttl      = 1
    }
    "seb-it.com/spf-mail" = {
      zone_key = "seb-it.com"
      name     = "mail"
      type     = "TXT"
      value    = "\"v=spf1 include:amazonses.com ~all\""
      ttl      = 1
    }
    "seb-it.com/spf" = {
      # No include at the apex: SES sends from mail.seb-it.com, and Email
      # Routing only forwards, rewriting the return path to its own domain.
      zone_key = "seb-it.com"
      name     = "seb-it.com"
      type     = "TXT"
      value    = "\"v=spf1 ~all\""
      ttl      = 1
    }
  }

  # Three DKIM CNAMEs per SES identity, token and record name are the same
  # string. The tokens belong to the identities in the aws stack, listing them
  # here would mean a DNS change every time one is rotated.
  ses_dkim_tokens = {
    "elmstreet79.de" = data.terraform_remote_state.aws.outputs.ses_elmstreet79.dkim_tokens
    "seb-it.com"     = data.terraform_remote_state.aws.outputs.ses_seb_it.dkim_tokens
  }

  ses_dkim_records = merge([
    for domain, tokens in local.ses_dkim_tokens : {
      for token in tokens :
      "${domain}/dkim-${token}-domainkey" => {
        zone_key = domain
        name     = "${token}._domainkey"
        type     = "CNAME"
        value    = "${token}.dkim.amazonses.com"
        ttl      = 1
      }
    }
  ]...)
}

resource "cloudflare_record" "mail" {
  for_each = merge(local.mail_records, local.ses_dkim_records)

  zone_id = var.sites[each.value.zone_key].zone_id
  # The provider keeps a subdomain's name relative ("mail"). A full name forces
  # replacement, which takes the zone's MX records down while it runs.
  name     = each.value.name
  type     = each.value.type
  content  = each.value.value
  priority = try(each.value.priority, null)
  # ttl and comment follow whatever the records already carry, so that adopting
  # them changes nothing.
  ttl     = each.value.ttl
  comment = try(each.value.comment, null)
  proxied = false
}
