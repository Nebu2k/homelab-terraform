output "backup_buckets" {
  description = "Versioning and retention state of the offsite backup buckets"
  value = {
    (var.paperless_bucket) = {
      versioning = aws_s3_bucket_versioning.paperless.versioning_configuration[0].status
      retention  = "multipart abort after ${var.multipart_abort_days} days, Object Lock GOVERNANCE ${var.paperless_object_lock_days} days per object"
    }
    (var.home_assistant_bucket) = {
      versioning = "Disabled"
      retention  = "depth is managed by Home Assistant itself, monthly archive '${var.home_assistant_archive_prefix}*' ${var.home_assistant_archive_days} days"
    }
    (var.teslamate_bucket) = {
      versioning = aws_s3_bucket_versioning.teslamate.versioning_configuration[0].status
      retention  = "'${var.teslamate_daily_prefix}' ${var.teslamate_daily_days} days, '${var.teslamate_monthly_prefix}' ${var.teslamate_monthly_days} days, noncurrent ${var.teslamate_noncurrent_days} days"
    }
    (var.etcd_snapshots_bucket) = {
      versioning = aws_s3_bucket_versioning.etcd_snapshots.versioning_configuration[0].status
      retention  = "lifecycle ${var.etcd_snapshot_days} days, noncurrent ${var.etcd_snapshot_noncurrent_days} days"
    }
    (var.mealie_bucket) = {
      versioning = aws_s3_bucket_versioning.mealie.versioning_configuration[0].status
      retention  = "'${var.mealie_daily_prefix}' ${var.mealie_daily_days} days, '${var.mealie_monthly_prefix}' ${var.mealie_monthly_days} days, noncurrent ${var.mealie_noncurrent_days} days"
    }
  }
}

# Where each backup consumer's key belongs, and which key is currently the
# right one. Not sensitive: an access key id identifies, it does not
# authenticate. The matching secrets are in "backup_consumer_secrets".
output "backup_consumer_users" {
  description = "IAM user per backup consumer, its current access key id and where that key belongs"
  value = {
    (aws_iam_user.teslamate_backup.name) = {
      access_key_id = aws_iam_access_key.teslamate_backup.id
      target        = "secret s3-teslamate-backup-credentials, namespace teslamate"
    }
    (aws_iam_user.paperless_backup.name) = {
      access_key_id = aws_iam_access_key.paperless_backup.id
      target        = "secret s3-backup-credentials, namespace paperless-ngx"
    }
    (aws_iam_user.home_assistant_backup.name) = {
      access_key_id = aws_iam_access_key.home_assistant_backup.id
      target        = "HA UI, S3 integration (not in the repo, lives on the Longhorn volume)"
    }
    (aws_iam_user.home_assistant_archive.name) = {
      access_key_id = aws_iam_access_key.home_assistant_archive.id
      target        = "secret s3-archive-credentials, namespace home-assistant"
    }
    (aws_iam_user.backup_monitor.name) = {
      access_key_id = aws_iam_access_key.backup_monitor.id
      target        = "secret s3-backup-monitor-credentials, namespace monitoring"
    }
    (aws_iam_user.etcd_backup.name) = {
      access_key_id = aws_iam_access_key.etcd_backup.id
      target        = "secret etcd-backup-s3, namespace kube-system"
    }
    (aws_iam_user.mealie_backup.name) = {
      access_key_id = aws_iam_access_key.mealie_backup.id
      target        = "secret s3-mealie-backup-credentials, namespace mealie"
    }
    (aws_iam_user.alertmanager.name) = {
      access_key_id = aws_iam_access_key.alertmanager.id
      target        = "secret alertmanager-aws-credentials, namespace monitoring"
    }
  }
}

# The secret halves, for filling the *-unsealed.yaml files before kubeseal:
#
#   terraform output -json backup_consumer_secrets
#
# One output for all eight rather than one each: after a rotation of several
# consumers the reseal run wants them together anyway.
output "backup_consumer_secrets" {
  description = "Secret access key per backup consumer"
  sensitive   = true
  value = {
    (aws_iam_user.teslamate_backup.name)       = aws_iam_access_key.teslamate_backup.secret
    (aws_iam_user.paperless_backup.name)       = aws_iam_access_key.paperless_backup.secret
    (aws_iam_user.home_assistant_backup.name)  = aws_iam_access_key.home_assistant_backup.secret
    (aws_iam_user.home_assistant_archive.name) = aws_iam_access_key.home_assistant_archive.secret
    (aws_iam_user.backup_monitor.name)         = aws_iam_access_key.backup_monitor.secret
    (aws_iam_user.etcd_backup.name)            = aws_iam_access_key.etcd_backup.secret
    (aws_iam_user.mealie_backup.name)          = aws_iam_access_key.mealie_backup.secret
    (aws_iam_user.alertmanager.name)           = aws_iam_access_key.alertmanager.secret
  }
}

# The topic_arn belongs in kubernetes-homelab/manifests/kube-prometheus-stack/
# values.yaml, the publisher's access key in the SealedSecret
# "alertmanager-aws-credentials" in the monitoring namespace.
output "alert_path" {
  description = "Topic, recipient and publishing IAM user of the alert path"
  value = {
    topic_arn = aws_sns_topic.alerts.arn
    email     = aws_sns_topic_subscription.alerts_email.endpoint
    publisher = aws_iam_user.alertmanager.name
  }
}

# Read by the websites stack through terraform_remote_state, which turns the
# tokens into CNAMEs. Nothing here is sensitive, all of it ends up in the zone.
output "ses_seb_it" {
  description = "SES identity of seb-it.com, adopted rather than created"
  value = {
    dkim_tokens      = aws_sesv2_email_identity.seb_it.dkim_signing_attributes[0].tokens
    mail_from_domain = aws_sesv2_email_identity_mail_from_attributes.seb_it.mail_from_domain
    sender           = aws_iam_user.seb_it_mail.name
  }
}

# For the mail client of seb-it.com. The hand made user "seb@seb-it.com" can go
# once these are in place.
output "seb_it_smtp_user" {
  description = "SMTP user of the seb-it.com mail client, the access key id"
  value       = aws_iam_access_key.seb_it_mail.id
}

output "seb_it_smtp_password" {
  description = "SMTP password of the seb-it.com mail client"
  value       = aws_iam_access_key.seb_it_mail.ses_smtp_password_v4
  sensitive   = true
}

