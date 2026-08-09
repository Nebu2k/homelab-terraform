# Offsite-Backup der Teslamate-Datenbank.
#
# Inhalt sind in sich geschlossene "pg_dump -Fc"-Staende unter den Praefixen
# "daily/" und "monthly/", erzeugt vom CronJob
# kubernetes-homelab/manifests/teslamate/backup-cronjob.yaml. Ein Dump liegt bei
# rund 60 MB.

resource "aws_s3_bucket" "teslamate" {
  bucket = var.teslamate_bucket

  # force_destroy steht auf dem Default false. S3 lehnt das Loeschen eines
  # befuellten Buckets mit BucketNotEmpty ab, prevent_destroy faengt den Fall
  # bereits im plan ab.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "teslamate-offsite-backup"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "teslamate" {
  bucket = aws_s3_bucket.teslamate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "teslamate" {
  bucket = aws_s3_bucket.teslamate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "teslamate" {
  bucket = aws_s3_bucket.teslamate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versioning ist aktiv und deckt das Ueberschreiben bestehender Keys ab; die
# vorherigen Dumps liegen dann als noncurrent version darunter und ueberleben
# teslamate_noncurrent_days. Es ist keine Retention, die Tiefe machen die
# Expiration-Regeln unten.
resource "aws_s3_bucket_versioning" "teslamate" {
  bucket = aws_s3_bucket.teslamate.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "teslamate" {
  bucket = aws_s3_bucket.teslamate.id

  # Die Dumps liegen ueber der 8-MB-Schwelle der AWS-CLI, jeder Upload ist ein
  # Multipart-Upload. Abgebrochene Teile sind im Listing unsichtbar und werden
  # berechnet.
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }

  rule {
    id     = "expire-daily-dumps"
    status = "Enabled"

    filter {
      prefix = var.teslamate_daily_prefix
    }

    expiration {
      days = var.teslamate_daily_days
    }
  }

  rule {
    id     = "expire-monthly-dumps"
    status = "Enabled"

    filter {
      prefix = var.teslamate_monthly_prefix
    }

    expiration {
      days = var.teslamate_monthly_days
    }
  }

  # In einem versionierten Bucket loescht "expiration" nicht, sondern setzt einen
  # Delete-Marker; die Daten liegen als noncurrent version darunter weiter.
  # noncurrent_version_expiration raeumt diese ab, expired_object_delete_marker
  # die allein zurueckbleibenden Marker.
  #
  # expired_object_delete_marker vertraegt sich nicht mit "days" im selben
  # expiration-Block, daher eine eigene Regel.
  rule {
    id     = "cleanup-noncurrent-and-markers"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.teslamate_noncurrent_days
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
