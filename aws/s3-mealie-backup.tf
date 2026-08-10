# Offsite-Backup der Mealie-Rezepte.
#
# Inhalt sind die ZIPs aus Mealies eingebautem Backup unter den Praefixen
# "daily/" und "monthly/", erzeugt vom CronJob
# kubernetes-homelab/manifests/mealie/backup-cronjob.yaml. Ein ZIP enthaelt den
# Datenbank-Stand UND das Data-Verzeichnis mit den Rezeptbildern und laesst sich
# ueber Mealies eigenen Restore-Endpunkt zurueckspielen. Deshalb hier ein ZIP
# statt eines pg_dump wie bei teslamate: der Dump allein waere nur die halbe
# Wiederherstellung, die Bilder liegen im Dateisystem.

resource "aws_s3_bucket" "mealie" {
  bucket = var.mealie_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "mealie-offsite-backup"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "mealie" {
  bucket = aws_s3_bucket.mealie.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "mealie" {
  bucket = aws_s3_bucket.mealie.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mealie" {
  bucket = aws_s3_bucket.mealie.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "mealie" {
  bucket = aws_s3_bucket.mealie.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mealie" {
  bucket = aws_s3_bucket.mealie.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }

  rule {
    id     = "expire-daily-backups"
    status = "Enabled"

    filter {
      prefix = var.mealie_daily_prefix
    }

    expiration {
      days = var.mealie_daily_days
    }
  }

  rule {
    id     = "expire-monthly-backups"
    status = "Enabled"

    filter {
      prefix = var.mealie_monthly_prefix
    }

    expiration {
      days = var.mealie_monthly_days
    }
  }

  # In einem versionierten Bucket loescht "expiration" nicht, sondern setzt einen
  # Delete-Marker. Ohne diese Regel liegen die Daten als noncurrent version
  # weiter da und kosten weiter. expired_object_delete_marker vertraegt sich
  # nicht mit "days" im selben expiration-Block, daher eine eigene Regel.
  rule {
    id     = "cleanup-noncurrent-and-markers"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.mealie_noncurrent_days
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
