# seb-it.com is the only domain that sends through SES. It receives through
# Cloudflare Email Routing, which only forwards, so answering as itself needs a
# sender of its own.
#
# The bootstrap policy "terraform-homelab-iam" (maintained by hand, see
# iam-backup-consumers.tf) needs the identity ARN in its SES statement,
# otherwise the plan fails with AccessDenied on GetEmailIdentity.

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

# The provider alias matters even though IAM is global: ses_smtp_password_v4 is
# an HMAC over the provider's region. Derived in Frankfurt it is rejected by the
# relay in Ireland with "535 Authentication Credentials Invalid".
resource "aws_iam_access_key" "seb_it_mail" {
  provider = aws.ireland

  user = aws_iam_user.seb_it_mail.name
}
