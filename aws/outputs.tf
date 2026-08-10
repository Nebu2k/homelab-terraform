output "backup_buckets" {
  description = "Versioning- und Retention-Stand der Offsite-Backup-Buckets"
  value = {
    (var.paperless_bucket) = {
      versioning = aws_s3_bucket_versioning.paperless.versioning_configuration[0].status
      retention  = "keine, nur Multipart-Abbruch nach ${var.multipart_abort_days} Tagen"
    }
    (var.home_assistant_bucket) = {
      versioning = "Disabled"
      retention  = "Tiefe steuert Home Assistant selbst, Monatsarchiv '${var.home_assistant_archive_prefix}*' ${var.home_assistant_archive_days} Tage"
    }
    (var.teslamate_bucket) = {
      versioning = aws_s3_bucket_versioning.teslamate.versioning_configuration[0].status
      retention  = "'${var.teslamate_daily_prefix}' ${var.teslamate_daily_days} Tage, '${var.teslamate_monthly_prefix}' ${var.teslamate_monthly_days} Tage, noncurrent ${var.teslamate_noncurrent_days} Tage"
    }
    (var.etcd_snapshots_bucket) = {
      versioning = aws_s3_bucket_versioning.etcd_snapshots.versioning_configuration[0].status
      retention  = "Lifecycle ${var.etcd_snapshot_days} Tage, noncurrent ${var.etcd_snapshot_noncurrent_days} Tage"
    }
    (var.mealie_bucket) = {
      versioning = aws_s3_bucket_versioning.mealie.versioning_configuration[0].status
      retention  = "'${var.mealie_daily_prefix}' ${var.mealie_daily_days} Tage, '${var.mealie_monthly_prefix}' ${var.mealie_monthly_days} Tage, noncurrent ${var.mealie_noncurrent_days} Tage"
    }
  }
}

# Terraform legt keine aws_iam_access_key an. Die Keys werden in der AWS-Konsole
# erzeugt und per kubeseal ins Cluster gebracht; dieser Output haelt fest, wohin
# der jeweilige Key gehoert.
output "backup_consumer_users" {
  description = "IAM-User je Backup-Konsument und wohin ihr Access Key gehoert"
  value = {
    (aws_iam_user.teslamate_backup.name)       = "Secret s3-teslamate-backup-credentials, Namespace teslamate"
    (aws_iam_user.paperless_backup.name)       = "Secret s3-backup-credentials, Namespace paperless-ngx"
    (aws_iam_user.home_assistant_backup.name)  = "HA-UI, S3-Integration (nicht im Repo, liegt auf dem Longhorn-Volume)"
    (aws_iam_user.home_assistant_archive.name) = "Secret s3-archive-credentials, Namespace home-assistant"
    (aws_iam_user.backup_monitor.name)         = "Secret s3-backup-monitor-credentials, Namespace monitoring"
    (aws_iam_user.etcd_backup.name)            = "Secret etcd-backup-s3, Namespace kube-system"
    (aws_iam_user.mealie_backup.name)          = "Secret s3-mealie-backup-credentials, Namespace mealie"
  }
}
