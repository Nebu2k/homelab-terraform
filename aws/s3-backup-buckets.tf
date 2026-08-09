# Die Buckets fuer paperless-ngx und Home Assistant.
#
# Public-Access-Block, Verschluesselung und Ownership sind hier beschrieben und
# nicht nur Konsolen-Zustand; eine Verstellung meldet der naechste plan als
# Drift.

resource "aws_s3_bucket" "paperless" {
  bucket = var.paperless_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "paperless-offsite-backup"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket" "home_assistant" {
  bucket = var.home_assistant_bucket

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "home-assistant-offsite-backup"
    ManagedBy = "terraform"
  }
}

# ===========================================
# paperless-ngx
# ===========================================

resource "aws_s3_bucket_public_access_block" "paperless" {
  bucket = aws_s3_bucket.paperless.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "paperless" {
  bucket = aws_s3_bucket.paperless.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "paperless" {
  bucket = aws_s3_bucket.paperless.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "paperless" {
  bucket = aws_s3_bucket.paperless.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Nur der Multipart-Abbruch, keine Retention. Der Sidecar synct ohne "--delete",
# der Bucket ist damit ein Archiv und kein Spiegel: er enthaelt auch Staende, zu
# denen kein Dokument mehr existiert.
resource "aws_s3_bucket_lifecycle_configuration" "paperless" {
  bucket = aws_s3_bucket.paperless.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }
}

# ===========================================
# Home Assistant
# ===========================================

resource "aws_s3_bucket_public_access_block" "home_assistant" {
  bucket = aws_s3_bucket.home_assistant.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "home_assistant" {
  bucket = aws_s3_bucket.home_assistant.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "home_assistant" {
  bucket = aws_s3_bucket.home_assistant.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Dieser Bucket ist unversioniert, es gibt fuer ihn keine
# aws_s3_bucket_versioning-Ressource. Die Tiefe der automatischen Backups
# steuert Home Assistant selbst ueber seine eigene Retention ("behalte N
# automatische Backups"), nicht eine Regel hier.
resource "aws_s3_bucket_lifecycle_configuration" "home_assistant" {
  bucket = aws_s3_bucket.home_assistant.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }

  # ---------------------------------------------------------------------------
  # Monatsarchiv.
  #
  # Eine monatliche HA-Automation erzeugt ein MANUELLES Backup. HAs Retention
  # greift ausschliesslich auf automatische Backups, ein manuelles bleibt
  # liegen, bis es geloescht wird; das uebernimmt diese Regel. Die Staende
  # landen als "<prefix>_<Datum>_<Zeit>_<ms>.tar" (+ .metadata.json) im
  # Bucket-Root, getrennt von "Automatic_backup_".
  #
  # Lifecycle-Filter koennen nicht negieren, "alles ausser Automatic_" gibt es
  # nicht. Die Regel haengt am literalen Praefix aus
  # var.home_assistant_archive_prefix; passt es nicht mehr zum Backup-Namen aus
  # der Automation, greift sie still nicht mehr.
  #
  # Der Bucket ist unversioniert, die Expiration loescht also direkt. Es
  # entstehen keine Delete-Marker, die nachzuraeumen waeren.
  rule {
    id     = "expire-monthly-archive"
    status = "Enabled"

    filter {
      prefix = var.home_assistant_archive_prefix
    }

    expiration {
      days = var.home_assistant_archive_days
    }
  }
}
