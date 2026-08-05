output "backup_buckets" {
  description = "Versioning- und Retention-Stand der Offsite-Backup-Buckets"
  value = {
    (var.paperless_bucket) = {
      versioning = aws_s3_bucket_versioning.paperless.versioning_configuration[0].status
      retention  = "keine, bis das Paperless-Backup-Konzept entschieden ist"
    }
    (var.home_assistant_bucket) = {
      versioning = "Disabled, bewusst (siehe s3-backup-buckets.tf)"
      retention  = "Tiefe steuert HA selbst, Monatsarchiv '${var.home_assistant_archive_prefix}*' ${var.home_assistant_archive_days} Tage"
    }
    (var.teslamate_bucket) = {
      versioning = aws_s3_bucket_versioning.teslamate.versioning_configuration[0].status
      retention  = "'${var.teslamate_daily_prefix}' ${var.teslamate_daily_days} Tage, '${var.teslamate_monthly_prefix}' ${var.teslamate_monthly_days} Tage, noncurrent ${var.teslamate_noncurrent_days} Tage"
    }
  }
}

# Der naechste Schritt nach dem apply ist ein Handgriff in der Konsole, deshalb
# steht er hier und nicht nur in der Doku: Terraform legt bewusst keine
# aws_iam_access_key an (Begruendung in iam-backup-consumers.tf), die Keys
# entstehen einmal in der Konsole und kommen per kubeseal ins Cluster.
output "backup_consumer_users" {
  description = "IAM-User je Backup-Konsument und wohin ihr Access Key gehoert"
  value = {
    (aws_iam_user.teslamate_backup.name)       = "Secret s3-teslamate-backup-credentials, Namespace teslamate"
    (aws_iam_user.paperless_backup.name)       = "Secret s3-backup-credentials, Namespace paperless-ngx"
    (aws_iam_user.home_assistant_backup.name)  = "HA-UI, S3-Integration (nicht im Repo, liegt auf dem Longhorn-Volume)"
    (aws_iam_user.home_assistant_archive.name) = "Secret s3-archive-credentials, Namespace home-assistant"
    (aws_iam_user.backup_monitor.name)         = "Secret s3-backup-monitor-credentials, Namespace monitoring"
  }
}
