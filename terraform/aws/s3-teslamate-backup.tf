# Offsite-Backup der Teslamate-Datenbank.
#
# Anders als die beiden Bestandsbuckets wird dieser hier vollstaendig von
# Terraform angelegt, es gibt keinen Konsolen-Zustand daneben. Der Inhalt sind
# in sich geschlossene "pg_dump -Fc"-Staende, erzeugt vom CronJob
# kubernetes-homelab/manifests/teslamate/backup-cronjob.yaml.
#
# Warum datierte Dumps und kein Sync: ein Dump ist fuer sich wiederherstellbar,
# es gibt keine Waisen, keinen Teilzustand und keine Frage "welche Datei gehoert
# zu welchem Stand". Genau die Punkte, an denen das Paperless-Konzept haengt.

resource "aws_s3_bucket" "teslamate" {
  bucket = var.teslamate_bucket

  # force_destroy bleibt aus (Default). Das ist hier die eigentliche
  # Schutzschicht und nicht bloss Kosmetik: S3 weigert sich, einen befuellten
  # Bucket zu loeschen, ein "terraform destroy" laeuft also in BucketNotEmpty
  # statt die einzige Offsite-Kopie zu entfernen. prevent_destroy unten kommt
  # obendrauf und faengt den Fall schon im plan ab.

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

# Versioning ist hier bewusst AN, obwohl es am HA-Bucket bewusst AUS ist. Das
# ist kein Widerspruch, die Bedingung aus s3-backup-buckets.tf ist hier von
# Anfang an erfuellt:
#
# Versioning schuetzt nur dann wirklich, wenn der schreibende Key die alten
# Versionen nicht selbst wegraeumen kann. Der Key dieses Buckets (siehe
# iam-backup-consumers.tf) hat weder DeleteObject noch DeleteObjectVersion, er
# darf ausschliesslich schreiben und lesen.
#
# Damit bleibt genau ein Angriff uebrig, den ein kompromittierter Cluster noch
# faehrt: bestehende Keys mit Muell UEBERSCHREIBEN. Dagegen wirkt Versioning,
# die echten Dumps liegen dann als noncurrent version darunter und ueberleben
# teslamate_noncurrent_days.
#
# Und es ist ausdruecklich KEINE Retention: die Tiefe machen die Expiration-
# Regeln unten, nicht die Versionen.
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

  # Der Dump liegt bei rund 60 MB und geht damit ueber die 8-MB-Schwelle der
  # AWS-CLI, jeder Upload ist also ein Multipart-Upload. Bricht einer ab,
  # bezahlt man die Teile weiter, ohne sie je zu sehen.
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

  # Aufraeumregel, die es NUR wegen des Versionings gibt. Ohne sie waechst der
  # Bucket unbemerkt weiter, obwohl oben "expiration" steht:
  #
  # 1. In einem versionierten Bucket loescht "expiration" nicht, sondern setzt
  #    einen Delete-Marker. Die eigentlichen Daten liegen als noncurrent version
  #    weiter da und kosten weiter Geld. Erst NoncurrentVersionExpiration raeumt
  #    sie ab.
  # 2. Ist die letzte echte Version weg, bleibt der Delete-Marker als einziges
  #    allein zurueck. expired_object_delete_marker kehrt diese Leichen aus.
  #
  # expired_object_delete_marker vertraegt sich nicht mit "days" im selben
  # expiration-Block, deshalb ist das hier eine eigene Regel und keine
  # Ergaenzung der beiden oben.
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
