# The two domains that send through SES. elmstreet79.de sends from the Postfix
# on pve, which has no other way out: the local resolver rewrites the domain to
# the Traefik VIP, so direct delivery cannot work. seb-it.com receives through
# Cloudflare Email Routing, which only forwards, so answering as itself needs a
# sender of its own.
#
# The bootstrap policy "terraform-homelab-iam" (maintained by hand, see
# iam-backup-consumers.tf) needs both identity ARNs in its SES statement,
# otherwise the plan fails with AccessDenied on GetEmailIdentity.

resource "aws_sesv2_email_identity" "elmstreet79" {
  provider = aws.ireland

  email_identity = var.ses_domain

  # Easy DKIM: AWS holds the private key and hands out three tokens that become
  # CNAMEs in the zone. Until they resolve the identity stays unverified and
  # SES refuses to send.
  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }

  tags = {
    Name      = "elmstreet79-sender"
    ManagedBy = "terraform"
  }
}

# Without a custom MAIL FROM the envelope sender is a subdomain of
# amazonses.com and SPF aligns with that instead of ours, leaving DMARC to rest
# on DKIM alone.
#
# Deliberately not REJECT_MESSAGE: if the MX of mail.elmstreet79.de is
# unreachable, SES falls back to its own envelope domain rather than dropping
# the mail.
resource "aws_sesv2_email_identity_mail_from_attributes" "elmstreet79" {
  provider = aws.ireland

  email_identity         = aws_sesv2_email_identity.elmstreet79.email_identity
  mail_from_domain       = var.ses_mail_from_domain
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_iam_user" "proxmox_mail" {
  name = "homelab-proxmox-mail"

  permissions_boundary = local.homelab_boundary_arn

  tags = {
    Name      = "proxmox-ses-sender"
    ManagedBy = "terraform"
  }
}

# The SMTP interface publishes as SendRawEmail. The identity ARN keeps the key
# from sending as any other domain.
resource "aws_iam_policy" "proxmox_mail" {
  name        = "proxmox-mail"
  path        = "/homelab/"
  description = "Senderecht des Proxmox-Postfix auf die Identität elmstreet79.de"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendAsElmstreet79"
        Effect   = "Allow"
        Action   = ["ses:SendRawEmail"]
        Resource = [aws_sesv2_email_identity.elmstreet79.arn]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "proxmox_mail" {
  user       = aws_iam_user.proxmox_mail.name
  policy_arn = aws_iam_policy.proxmox_mail.arn
}

# SMTP does not take the secret key itself but an HMAC of it over the region,
# and Terraform is the only thing here that derives it. The alternative is the
# SES console, which creates an IAM user of its own and would sidestep the user
# above.
#
# The provider alias matters even though IAM is global: ses_smtp_password_v4 is
# an HMAC over the provider's region. Derived in Frankfurt it is rejected by
# the relay in Ireland with "535 Authentication Credentials Invalid".
resource "aws_iam_access_key" "proxmox_mail" {
  provider = aws.ireland

  user = aws_iam_user.proxmox_mail.name
}

# Adopted, not created: this identity has been sending for a while. No
# dkim_signing_attributes block on purpose, it would let Terraform rotate the
# signing key and with it the three CNAMEs in the zone.
import {
  to = aws_sesv2_email_identity.seb_it
  id = "seb-it.com"
}

import {
  to = aws_sesv2_email_identity_mail_from_attributes.seb_it
  id = "seb-it.com"
}

resource "aws_sesv2_email_identity" "seb_it" {
  provider = aws.ireland

  email_identity = "seb-it.com"

  tags = {
    Name      = "seb-it-sender"
    ManagedBy = "terraform"
  }
}

resource "aws_sesv2_email_identity_mail_from_attributes" "seb_it" {
  provider = aws.ireland

  email_identity         = aws_sesv2_email_identity.seb_it.email_identity
  mail_from_domain       = "mail.seb-it.com"
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

# Replaces the hand made IAM user "seb@seb-it.com", which Terraform cannot
# adopt: the bootstrap policy only reaches user/homelab-*. The old one stays
# until its credentials are out of the mail client.
resource "aws_iam_user" "seb_it_mail" {
  name = "homelab-seb-it-mail"

  permissions_boundary = local.homelab_boundary_arn

  tags = {
    Name      = "seb-it-ses-sender"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_policy" "seb_it_mail" {
  name        = "seb-it-mail"
  path        = "/homelab/"
  description = "Senderecht des Mailclients auf die Identität seb-it.com"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendAsSebIt"
        Effect   = "Allow"
        Action   = ["ses:SendRawEmail"]
        Resource = [aws_sesv2_email_identity.seb_it.arn]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "seb_it_mail" {
  user       = aws_iam_user.seb_it_mail.name
  policy_arn = aws_iam_policy.seb_it_mail.arn
}

resource "aws_iam_access_key" "seb_it_mail" {
  provider = aws.ireland

  user = aws_iam_user.seb_it_mail.name
}
