# The buckets for paperless-ngx and Home Assistant.
#
# Public access block, encryption and ownership are described here and are not
# just console state; the next plan reports any change to them as drift.

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

# Only the multipart abort, no retention. The sidecar syncs without
# "--delete", which makes the bucket an archive rather than a mirror: it also
# holds states for documents that no longer exist.
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

# This bucket is unversioned, there is no aws_s3_bucket_versioning resource
# for it. The depth of the automatic backups is managed by Home Assistant
# itself through its own retention ("keep N automatic backups"), not by a rule
# here.
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
  # Monthly archive.
  #
  # A monthly HA automation creates a MANUAL backup. HA's retention applies to
  # automatic backups only, a manual one stays until it is deleted; that is
  # what this rule does. The states land as "<prefix>_<date>_<time>_<ms>.tar"
  # (+ .metadata.json) in the bucket root, separate from "Automatic_backup_".
  #
  # Lifecycle filters cannot negate, there is no "everything except
  # Automatic_". The rule hangs off the literal prefix from
  # var.home_assistant_archive_prefix; if that no longer matches the backup
  # name from the automation, it silently stops matching.
  #
  # The bucket is unversioned, so the expiration deletes directly. No delete
  # markers are created that would need cleaning up.
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
