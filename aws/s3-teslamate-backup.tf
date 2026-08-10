# Offsite backup of the Teslamate database.
#
# The content is self-contained "pg_dump -Fc" states under the prefixes
# "daily/" and "monthly/", produced by the CronJob
# kubernetes-homelab/manifests/teslamate/backup-cronjob.yaml. A dump is around
# 60 MB.

resource "aws_s3_bucket" "teslamate" {
  bucket = var.teslamate_bucket

  # force_destroy is left at its default of false. S3 refuses to delete a
  # populated bucket with BucketNotEmpty, and prevent_destroy catches the case
  # in the plan already.
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

# Versioning is on and covers overwriting existing keys; the previous dumps
# then sit underneath as noncurrent versions and survive
# teslamate_noncurrent_days. It is not a retention, the depth comes from the
# expiration rules below.
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

  # The dumps are above the 8 MB threshold of the AWS CLI, so every upload is
  # a multipart upload. Aborted parts are invisible in the listing and still
  # billed.
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

  # In a versioned bucket "expiration" does not delete, it places a delete
  # marker; the data stays underneath as a noncurrent version.
  # noncurrent_version_expiration clears those out, expired_object_delete_marker
  # the markers left behind on their own.
  #
  # expired_object_delete_marker cannot be combined with "days" in the same
  # expiration block, hence a rule of its own.
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
