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
# steht er hier und nicht nur in der Doku.
output "teslamate_backup_user" {
  description = "IAM-User des Teslamate-Backups. Access Key dafuer von Hand in der Konsole erzeugen, Terraform tut das bewusst nicht (siehe iam-backup-consumers.tf)."
  value       = aws_iam_user.teslamate_backup.name
}
