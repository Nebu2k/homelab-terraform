output "backup_buckets" {
  description = "Versioning and retention state of the offsite backup buckets"
  value = {
    (var.paperless_bucket) = {
      versioning = aws_s3_bucket_versioning.paperless.versioning_configuration[0].status
      retention  = "none, only multipart abort after ${var.multipart_abort_days} days"
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

# Terraform creates no aws_iam_access_key. The keys are generated in the AWS
# console and brought into the cluster with kubeseal; this output records where
# each key belongs.
output "backup_consumer_users" {
  description = "IAM user per backup consumer and where its access key belongs"
  value = {
    (aws_iam_user.teslamate_backup.name)       = "secret s3-teslamate-backup-credentials, namespace teslamate"
    (aws_iam_user.paperless_backup.name)       = "secret s3-backup-credentials, namespace paperless-ngx"
    (aws_iam_user.home_assistant_backup.name)  = "HA UI, S3 integration (not in the repo, lives on the Longhorn volume)"
    (aws_iam_user.home_assistant_archive.name) = "secret s3-archive-credentials, namespace home-assistant"
    (aws_iam_user.backup_monitor.name)         = "secret s3-backup-monitor-credentials, namespace monitoring"
    (aws_iam_user.etcd_backup.name)            = "secret etcd-backup-s3, namespace kube-system"
    (aws_iam_user.mealie_backup.name)          = "secret s3-mealie-backup-credentials, namespace mealie"
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
