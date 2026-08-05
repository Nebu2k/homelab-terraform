output "backup_buckets" {
  description = "Versioning- und Retention-Stand der beiden Offsite-Backup-Buckets"
  value = {
    (var.paperless_bucket) = {
      versioning = aws_s3_bucket_versioning.paperless.versioning_configuration[0].status
      retention  = "keine, bis das Paperless-Backup-Konzept entschieden ist"
    }
    (var.home_assistant_bucket) = {
      versioning = "Disabled, bewusst (siehe s3-backup-buckets.tf)"
      retention  = "Tiefe steuert HA selbst, Monatsarchiv '${var.home_assistant_archive_prefix}*' ${var.home_assistant_archive_days} Tage"
    }
  }
}
