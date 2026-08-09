# Offsite-Ablage der etcd-Snapshots der drei Control-Plane-Nodes.
#
# Inhalt: ein Snapshot je Node und Lauf, Objektname
# "etcd-snapshot-<node>-<unix-ts>" im Bucket-Root. Ein Snapshot liegt bei rund
# 55 MB. Geschrieben wird von drei CronJobs im Cluster (kube-system, Manifeste
# in kubernetes-homelab/manifests/etcd-backup/), je einer pro Control-Plane,
# zweimal taeglich und gestaffelt. Talos laedt Snapshots nicht selbst hoch, es
# gibt sie nur ueber die API heraus.
#
# Ein Snapshot enthaelt jedes Secret des Clusters. Die Cluster-Secrets sind in
# etcd verschluesselt abgelegt (cluster.secretboxEncryptionSecret in der Machine
# Config); der zugehoerige Schluessel steht in talsecret.sops.yaml und ist ohne
# den privaten age-Key nicht lesbar. Ohne diesen Schluessel ist ein Snapshot aus
# diesem Bucket nicht wiederherstellbar.

resource "aws_s3_bucket" "etcd_snapshots" {
  bucket = var.etcd_snapshots_bucket

  # force_destroy steht auf dem Default false. S3 lehnt das Loeschen eines
  # befuellten Buckets mit BucketNotEmpty ab, prevent_destroy faengt den Fall
  # bereits im plan ab.
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

# Versioning ist aktiv. Es wirkt nicht rueckwirkend, geschuetzt ist nur, was
# danach geschrieben wurde.
resource "aws_s3_bucket_versioning" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Die Tiefe des Buckets kommt ausschliesslich aus diesen Regeln. Die CronJobs
# laden nur hoch und loeschen nichts.
#
# Der Bucket dient ausschliesslich diesem Zweck, die Regeln greifen deshalb ohne
# Praefix-Filter ueber den gesamten Inhalt.
resource "aws_s3_bucket_lifecycle_configuration" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  # Snapshots liegen ueber der 8-MB-Schwelle der AWS-CLI und gehen als Multipart
  # hoch. Abgebrochene Teile sind im Listing unsichtbar und werden berechnet.
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
      noncurrent_days = var.etcd_snapshot_noncurrent_days
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}
