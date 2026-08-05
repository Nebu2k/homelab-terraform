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

# Versioning AN, und hier traegt es mehr als an den anderen Buckets, weil dieser
# Key als einer von zweien DeleteObject hat (Begruendung in
# iam-backup-consumers.tf: k3s fuehrt seine Retention selbst und die S3-Tiefe
# laesst sich nicht davon trennen).
#
# Ihm fehlt DeleteObjectVersion. Jedes Loeschen, ob von k3s oder von jemandem
# mit dem Key in der Hand, setzt damit nur einen Delete-Marker. Der Snapshot
# liegt als noncurrent version darunter und ueberlebt
# etcd_snapshot_noncurrent_days. Ohne Versioning waere dieser Bucket der einzige
# Offsite-Ort der Sealing-Keys UND per Key ausraeumbar.
#
# ACHTUNG: Versioning wirkt nicht rueckwirkend. Es stand von Anfang an an.
resource "aws_s3_bucket_versioning" "etcd_snapshots" {
  bucket = aws_s3_bucket.etcd_snapshots.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Aufgeraeumt wird hier ZWEIMAL, und das ist Absicht.
#
# Erstens raeumt k3s selbst: --etcd-snapshot-retention (28, also 14 Tage bei zwei
# Laeufen taeglich) gilt lokal und in S3. Das ist der Normalbetrieb.
#
# Zweitens raeumen diese Regeln, und sie sind kein Zierrat, sondern fangen genau
# die Faelle, in denen k3s es nicht tut: eine Node, die dauerhaft weg ist und
# ihre Snapshots nie wieder anfasst, ein Fehlschlag beim Loeschen, oder die
# noncurrent versions, die k3s' Delete-Marker hinterlaesst und die es selbst
# gar nicht sehen kann.
#
# Der Bucket gehoert ausschliesslich diesem einen Zweck, deshalb greifen die
# Regeln ohne Praefix-Filter. Es gibt hier bewusst kein "--etcd-s3-folder": eine
# Praefix-Kopplung zwischen Node-Flag und Lifecycle-Regel waere eine weitere
# Stelle, die beim Auseinanderlaufen still die Aufraeumung abschaltet. Und
# ohnehin waere jedes weitere --etcd-s3-*-Flag an der Unit fatal, es schaltet
# das Config-Secret ab.
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
