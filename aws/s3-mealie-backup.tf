# Offsite backup of the Mealie recipes.
#
# The content is the ZIPs from Mealie's built-in backup under the prefixes
# "daily/" and "monthly/", produced by the CronJob
# kubernetes-homelab/manifests/mealie/backup-cronjob.yaml. A ZIP contains the
# database state AND the data directory with the recipe images, and can be
# restored through Mealie's own restore endpoint. Hence a ZIP here instead of a
# pg_dump like teslamate: the dump alone would only be half the recovery, the
# images live in the filesystem.

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

  # In a versioned bucket "expiration" does not delete, it places a delete
  # marker. Without this rule the data stays around as a noncurrent version and
  # keeps costing. expired_object_delete_marker cannot be combined with "days"
  # in the same expiration block, hence a rule of its own.
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
