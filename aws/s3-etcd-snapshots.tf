# Offsite storage of the etcd snapshots of the three control plane nodes.
#
# Content: one snapshot per node and run, object name
# "etcd-snapshot-<node>-<unix-ts>" in the bucket root. A snapshot is around
# 55 MB. Written by three CronJobs in the cluster (kube-system, manifests in
# kubernetes-homelab/manifests/etcd-backup/), one per control plane, twice a
# day and staggered. Talos does not upload snapshots itself, it only hands
# them out over the API.
#
# A snapshot contains every secret of the cluster. The cluster secrets are
# stored encrypted in etcd (cluster.secretboxEncryptionSecret in the machine
# config); the matching key lives in talsecret.sops.yaml and is unreadable
# without the private age key. Without that key a snapshot from this bucket
# cannot be restored.

resource "aws_s3_bucket" "etcd_snapshots" {
  bucket = var.etcd_snapshots_bucket

  # force_destroy is left at its default of false. S3 refuses to delete a
  # populated bucket with BucketNotEmpty, and prevent_destroy catches the case
  # in the plan already.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "etcd-snapshot-offsite"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versioning is on. It does not apply retroactively, only what was written
# afterwards is protected.
resource "aws_s3_bucket_versioning" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# The depth of the bucket comes from these rules alone. The CronJobs only
# upload and never delete.
#
# The bucket serves this one purpose, so the rules apply to its entire content
# without a prefix filter.
resource "aws_s3_bucket_lifecycle_configuration" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  # Snapshots are above the 8 MB threshold of the AWS CLI and go up as
  # multipart. Aborted parts are invisible in the listing and still billed.
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }

  rule {
    id     = "expire-snapshots"
    status = "Enabled"

    filter {}

    expiration {
      days = var.etcd_snapshot_days
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
      noncurrent_days = var.etcd_snapshot_noncurrent_days
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
