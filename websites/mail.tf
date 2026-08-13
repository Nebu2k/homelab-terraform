# MX, SPF, DMARC and DKIM of every zone in var.sites, minus the records
# Email Routing owns on seb-it.com: the API rejects every write to those
# with error 1046. seb-it.com receives through Email Routing, which cannot
# send, so it sends through SES from mail.seb-it.com. The other four
# receive and send through iCloud; their SES records are unused.

locals {
  mail_records = {
    "elmstreet79.de/dkim-2uq7sudnyih6jds3tqjkoahluv62ixr3-domainkey" = {
      zone_key = "elmstreet79.de"
      name     = "2uq7sudnyih6jds3tqjkoahluv62ixr3._domainkey"
      type     = "CNAME"
      value    = "2uq7sudnyih6jds3tqjkoahluv62ixr3.dkim.amazonses.com"
      ttl      = 1
      comment  = "Amazon SES"
    }
    "elmstreet79.de/dkim-622m63merp3oibyi7hgveurd2ihotgqt-domainkey" = {
      zone_key = "elmstreet79.de"
      name     = "622m63merp3oibyi7hgveurd2ihotgqt._domainkey"
      type     = "CNAME"
      value    = "622m63merp3oibyi7hgveurd2ihotgqt.dkim.amazonses.com"
      ttl      = 1
      comment  = "Amazon SES"
    }
    "elmstreet79.de/dkim-ou7mhac4hifcqpacv2m7boh6hnxamsnl-domainkey" = {
      zone_key = "elmstreet79.de"
      name     = "ou7mhac4hifcqpacv2m7boh6hnxamsnl._domainkey"
      type     = "CNAME"
      value    = "ou7mhac4hifcqpacv2m7boh6hnxamsnl.dkim.amazonses.com"
      ttl      = 1
      comment  = "Amazon SES"
    }
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
      zone_key = "elmstreet79.de"
      name     = "elmstreet79.de"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
      comment  = "SPF"
    }
    "haushelden-service.de/dkim-bhzh2yjfucuikvcvquhbzinssz4x7g23-domainkey" = {
      zone_key = "haushelden-service.de"
      name     = "bhzh2yjfucuikvcvquhbzinssz4x7g23._domainkey"
      type     = "CNAME"
      value    = "bhzh2yjfucuikvcvquhbzinssz4x7g23.dkim.amazonses.com"
      ttl      = 1
    }
    "haushelden-service.de/dkim-i7oo3o3x3zt4pxfebqjm24cccgubzyi5-domainkey" = {
      zone_key = "haushelden-service.de"
      name     = "i7oo3o3x3zt4pxfebqjm24cccgubzyi5._domainkey"
      type     = "CNAME"
      value    = "i7oo3o3x3zt4pxfebqjm24cccgubzyi5.dkim.amazonses.com"
      ttl      = 1
    }
    "haushelden-service.de/dkim-kmb4q4fc4els7dwqpt3iuveqskkzwt65-domainkey" = {
      zone_key = "haushelden-service.de"
      name     = "kmb4q4fc4els7dwqpt3iuveqskkzwt65._domainkey"
      type     = "CNAME"
      value    = "kmb4q4fc4els7dwqpt3iuveqskkzwt65.dkim.amazonses.com"
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
    "haushelden-service.de/mx-mail" = {
      zone_key = "haushelden-service.de"
      name     = "mail"
      type     = "MX"
      value    = "feedback-smtp.eu-west-1.amazonses.com"
      ttl      = 1
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
      # No include:amazonses.com here: SES sends from mail.haushelden-service.de, which
      # carries its own record, and SPF checks the envelope sender.
      zone_key = "haushelden-service.de"
      name     = "haushelden-service.de"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
    }
    "haushelden-service.de/spf-mail" = {
      zone_key = "haushelden-service.de"
      name     = "mail"
      type     = "TXT"
      value    = "\"v=spf1 include:amazonses.com ~all\""
      ttl      = 1
    }
    "homeworx.solutions/dkim-5xwzbj3kr7oizwrjg6z5shdts6iezkqn-domainkey" = {
      zone_key = "homeworx.solutions"
      name     = "5xwzbj3kr7oizwrjg6z5shdts6iezkqn._domainkey"
      type     = "CNAME"
      value    = "5xwzbj3kr7oizwrjg6z5shdts6iezkqn.dkim.amazonses.com"
      ttl      = 1
    }
    "homeworx.solutions/dkim-b455avma2wosebivnejgc2nhydgoa5yn-domainkey" = {
      zone_key = "homeworx.solutions"
      name     = "b455avma2wosebivnejgc2nhydgoa5yn._domainkey"
      type     = "CNAME"
      value    = "b455avma2wosebivnejgc2nhydgoa5yn.dkim.amazonses.com"
      ttl      = 1
    }
    "homeworx.solutions/dkim-sig1-domainkey" = {
      zone_key = "homeworx.solutions"
      name     = "sig1._domainkey"
      type     = "CNAME"
      value    = "sig1.dkim.homeworx.solutions.at.icloudmailadmin.com"
      ttl      = 3600
    }
    "homeworx.solutions/dkim-t4bcyuw6uoitrsjmzyhgfqqo5lvcut4u-domainkey" = {
      zone_key = "homeworx.solutions"
      name     = "t4bcyuw6uoitrsjmzyhgfqqo5lvcut4u._domainkey"
      type     = "CNAME"
      value    = "t4bcyuw6uoitrsjmzyhgfqqo5lvcut4u.dkim.amazonses.com"
      ttl      = 1
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
    "homeworx.solutions/mx-mail" = {
      zone_key = "homeworx.solutions"
      name     = "mail"
      type     = "MX"
      value    = "feedback-smtp.eu-west-1.amazonses.com"
      ttl      = 1
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
      # No include:amazonses.com here: SES sends from mail.homeworx.solutions, which
      # carries its own record, and SPF checks the envelope sender.
      zone_key = "homeworx.solutions"
      name     = "homeworx.solutions"
      type     = "TXT"
      value    = "\"v=spf1 include:icloud.com ~all\""
      ttl      = 3600
    }
    "homeworx.solutions/spf-mail" = {
      zone_key = "homeworx.solutions"
      name     = "mail"
      type     = "TXT"
      value    = "\"v=spf1 include:amazonses.com ~all\""
      ttl      = 1
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
    "seb-it.com/dkim-5khisw3yaoxshqgoypyu7eb4qekw7d4p-domainkey" = {
      zone_key = "seb-it.com"
      name     = "5khisw3yaoxshqgoypyu7eb4qekw7d4p._domainkey"
      type     = "CNAME"
      value    = "5khisw3yaoxshqgoypyu7eb4qekw7d4p.dkim.amazonses.com"
      ttl      = 1
    }
    "seb-it.com/dkim-6wravi266iecnbqwwtiqa74jyjfvvnaf-domainkey" = {
      zone_key = "seb-it.com"
      name     = "6wravi266iecnbqwwtiqa74jyjfvvnaf._domainkey"
      type     = "CNAME"
      value    = "6wravi266iecnbqwwtiqa74jyjfvvnaf.dkim.amazonses.com"
      ttl      = 1
    }
    "seb-it.com/dkim-adf7ntu4qr3yaczhxhcx5lwvhodri5mb-domainkey" = {
      zone_key = "seb-it.com"
      name     = "adf7ntu4qr3yaczhxhcx5lwvhodri5mb._domainkey"
      type     = "CNAME"
      value    = "adf7ntu4qr3yaczhxhcx5lwvhodri5mb.dkim.amazonses.com"
      ttl      = 1
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
      zone_key = "seb-it.com"
      name     = "seb-it.com"
      type     = "TXT"
      value    = "\"v=spf1 include:amazonses.com include:_spf.mx.cloudflare.net ~all\""
      ttl      = 1
    }
  }
}

resource "cloudflare_record" "mail" {
  for_each = local.mail_records

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
