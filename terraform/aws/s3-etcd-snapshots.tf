# Offsite-Ablage der etcd-Snapshots der drei k3s-Server-Nodes.
#
# ================== Warum es diesen Bucket gibt ==================
#
# Nicht wegen etcd. Der Cluster-State liegt per GitOps im Repo und waere aus
# leerem Blech nachbaubar. Es geht um die 25 SealedSecrets darin: entschluesseln
# kann sie ausschliesslich der Sealing-Key aus dem Namespace kube-system, und
# der existierte bis hierher NUR in etcd. etcd-Snapshots lagen nur auf den
# Server-Nodes selbst. Gehen cp-1, raspi4 und raspi5 gemeinsam verloren, waere
# jedes Secret im Repo Datenmuell und muesste bei 25 Diensten neu beschafft
# werden. Das ist der teuerste Einzelverlust im ganzen Aufbau und der einzige,
# den weder Longhorn noch die drei App-Buckets abdecken.
#
# Der Weg ueber k3s' eingebautes "--etcd-s3" statt eines eigenen Export-Jobs:
# k3s laedt seine ohnehin alle 12h erzeugten Snapshots selbst hoch, es kommt
# kein weiterer Dienst dazu, und die Sealing-Key-Rotation alle 30 Tage ist
# automatisch mit drin.
#
# ================== Der Inhalt ist heikler als bei den anderen dreien ==========
#
# Ein etcd-Snapshot enthaelt JEDES Secret des Clusters, nicht nur die Sealing-
# Keys. Das ist der Grund, warum "--secrets-encryption" auf den Server-Nodes
# eingeschaltet wurde, bevor der erste Snapshot hier landete: ohne den Schalter
# laegen alle Cluster-Secrets im Klartext in diesem Bucket.
#
# Damit haengt an diesem Bucket eine Bedingung, die die anderen drei nicht
# haben: er ist nur so gut wie der Zustand von "k3s secrets-encrypt status".
# Steht der je wieder auf Disabled, ist der Inhalt hier Klartext.
#
# Umgekehrt gilt: ohne /var/lib/rancher/k3s/server/cred/encryption-config.json
# ist ein Snapshot von hier NICHT wiederherstellbar. Diese Datei ist rund 1 KB
# gross, aendert sich nur bei einer Key-Rotation und gehoert deshalb ins
# Notfall-Kit auf Sebastians Mac, genau wie der HA-Backup-Key. Ein Bucket voll
# Snapshots ohne diese Datei ist wertlos.

resource "aws_s3_bucket" "etcd_snapshots" {
  bucket = var.etcd_snapshots_bucket

  # force_destroy bleibt aus (Default), siehe die Begruendung an den anderen
  # Buckets: S3 lehnt das Loeschen eines befuellten Buckets mit BucketNotEmpty
  # ab, der Schutz sitzt an der API und nicht daran, ob Terraform ihn kennt.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "k3s-etcd-snapshots"
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

# Versioning AN, aus demselben Grund wie beim Teslamate-Bucket: der schreibende
# Key (homelab-etcd-backup) hat weder DeleteObject noch DeleteObjectVersion.
# Damit bleibt einem kompromittierten Cluster nur das Ueberschreiben, und genau
# dagegen wirkt Versioning.
#
# Die Snapshot-Keys tragen einen Unix-Zeitstempel und wiederholen sich im
# Normalbetrieb nie. Ein Ueberschreiben waere also immer Absicht, und zwar
# fremde.
resource "aws_s3_bucket_versioning" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Aufgeraeumt wird ausschliesslich hier, NICHT durch k3s.
#
# k3s hat mit "--etcd-s3-retention" eine eigene Retention, die alte Snapshots
# aus dem Bucket loescht. Die ist bewusst auf einen Wert gesetzt, den der Bucket
# nie erreicht (siehe etcd_s3_retention in variables.tf), damit der IAM-User
# ohne DeleteObject auskommt. Bei 2 Snapshots taeglich auf 3 Nodes und
# etcd_snapshot_days Aufbewahrung pendelt sich der Bucket bei rund 180 Objekten
# ein, k3s kommt also nie in die Naehe seiner Schwelle und versucht nie zu
# loeschen.
#
# Der Bucket gehoert ausschliesslich diesem einen Zweck, deshalb greifen die
# Regeln ohne Praefix-Filter. Es gibt hier bewusst kein "--etcd-s3-folder": eine
# Praefix-Kopplung zwischen Node-Flag und Lifecycle-Regel waere eine weitere
# Stelle, die beim Auseinanderlaufen still die Aufraeumung abschaltet.
resource "aws_s3_bucket_lifecycle_configuration" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  # Ein Snapshot liegt bei rund 48 MB und damit ueber der 8-MB-Schwelle, ab der
  # in Teilen hochgeladen wird. Abgebrochene Teile sind unsichtbar und werden
  # trotzdem berechnet.
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

  # Dieselbe Falle wie am Teslamate-Bucket: in einem versionierten Bucket
  # loescht "expiration" nicht, sondern setzt einen Delete-Marker. Ohne
  # noncurrent_version_expiration liegen die Snapshots darunter weiter und
  # kosten weiter, und expired_object_delete_marker kehrt die allein
  # zurueckbleibenden Marker aus.
  #
  # expired_object_delete_marker vertraegt sich nicht mit "days" im selben
  # expiration-Block, deshalb eine eigene Regel.
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
