# Die beiden Bestandsbuckets fuer Paperless und Home Assistant. Sie wurden am
# 2026-08-05 in Terraform importiert und sind seitdem vollstaendig hier
# beschrieben, genauso wie der Teslamate-Bucket.
#
# Warum sie vorher nur als data-Quelle drinstanden und was daran falsch war:
# die Sorge war, ein importierter Bucket sei per "terraform destroy" oder einem
# geloeschten Resource-Block zerstoerbar. Das stimmt so nicht. "force_destroy"
# steht auf dem Default false, und dann weigert sich S3 selbst, einen befuellten
# Bucket zu loeschen: der Aufruf laeuft in BucketNotEmpty. Der eigentliche
# Schutz sitzt also an der API und nicht an der Frage, ob Terraform den Bucket
# kennt. prevent_destroy kommt obendrauf und faengt den Fall schon im plan ab.
#
# Der Preis des alten Zustands war dagegen real: Public-Access-Block,
# Verschluesselung und Ownership waren reiner Konsolen-Zustand. Verstellt die
# jemand, faellt das nirgends auf, kein plan meldet Drift. Genau diese drei
# Einstellungen halten die Buckets privat.
#
# Der Import hat NICHTS an den Buckets geaendert (Werte vorab gegen die API
# geprueft), einzige Ausnahme sind die Tags weiter unten, die es vorher nicht gab.

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

# Versioning ist an diesem Bucket seit jeher aktiv und wird hier nur festgehalten.
resource "aws_s3_bucket_versioning" "paperless" {
  bucket = aws_s3_bucket.paperless.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# BEWUSST nur der Multipart-Abbruch, keine Retention. Der Sidecar synct ohne
# "--delete", der Bucket ist damit ein Archiv und kein Spiegel: rund 27 der 218
# Objekte gehoeren zu keinem existierenden Dokument mehr (gemessen 2026-08-04).
# Eine Expiration auf ein Ablageschema zu setzen, das selbst noch nicht rund
# ist, zementiert nur den Ist-Zustand. Erst das Konzept (append-only / Spiegel /
# datierte Zips) entscheiden, dann hier nachziehen.
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

# Dieser Bucket ist BEWUSST unversioniert, und die Tiefe steht BEWUSST nicht
# hier, sondern in HAs eigener Retention ("behalte N automatische Backups").
# Es gibt deshalb absichtlich KEINE aws_s3_bucket_versioning-Ressource fuer ihn.
#
# Warum keine NoncurrentVersionExpiration als Tiefe: HA zaehlt Kopien, Lifecycle
# zaehlt Tage seit dem Loeschen. Zwei Mechanismen fuer dieselbe Aussage driften
# auseinander, sobald ein Backup-Lauf ausfaellt, und niemand weiss spaeter, welche
# Zahl gewinnt. Wer mehr Staende will, dreht an HA, an einer Stelle.
#
# Warum ueberhaupt kein Versioning: sein einziger Nutzen jenseits von Retention
# ist der Schutz gegen ein Loeschen, das HA nicht gewollt hat. Der greift nur,
# wenn der loeschende Key kein DeleteObjectVersion hat. Aktuell bedienen
# Paperless und HA denselben IAM-Key "homelab-backup", und der darf
# DeleteObject auf beiden Buckets. Versioning waere hier also ein
# Sicherheits-Anstrich ohne Sicherheit.
#
# NACHTRAG 2026-08-05: die zweite Haelfte der alten Begruendung ("Rechte
# ungeprueft") ist erledigt, die Policy ist auditiert und steht im Wortlaut in
# betrieb.md. DeleteObjectVersion fehlt ihr, DeleteObject nicht. Es bleibt also
# beim selben Ergebnis, nur aus belegtem statt aus unbekanntem Grund.
#
# Es kommt zurueck, wenn der Key pro Konsument getrennt und bucket-scoped ohne
# Delete-Rechte ausgestellt ist (Roadmap Punkt 4, Vorlage in
# iam-backup-consumers.tf). Dann als Ransomware-Schutz mit kleinem Fenster,
# ausdruecklich nicht als Retention. Achtung: Versioning wirkt nicht
# rueckwirkend, geschuetzt ist erst, was danach geschrieben wird.
#
# Der weit zurueckliegende Wiederherstellungspunkt kommt stattdessen aus dem
# Monatsarchiv unten.
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
  # Monatsarchiv, der eigentliche Backup-des-Backups-Punkt.
  #
  # Eine monatliche HA-Automation erzeugt ein MANUELLES Backup. HAs Retention
  # ("behalte N") greift ausschliesslich auf automatische Backups, ein manuelles
  # bleibt also liegen, bis es jemand loescht. Genau das uebernimmt diese Regel.
  #
  # Belegt am 2026-08-05: ein manuell mit dem Namen "Monthly" erstelltes Backup
  # erreicht den S3-Agenten und landet als "Monthly_<Datum>_<Zeit>_<ms>.tar"
  # (+ .metadata.json) im Bucket-Root, sauber getrennt von "Automatic_backup_".
  #
  # ACHTUNG, die zwei Fallen an dieser Regel:
  #
  # 1. Lifecycle-Filter koennen NICHT negieren. "Alles ausser Automatic_" gibt es
  #    nicht, die Regel haengt zwingend am literalen Praefix. Aendert jemand den
  #    Backup-Namen in der Automation, greift sie still nicht mehr und die
  #    Archivstaende wachsen unbegrenzt. Deshalb steht das Praefix in einer
  #    Variablen und nicht als Literal hier.
  # 2. Die 180 Tage sind bewusst kein Jahr. Ein HA-Backup altert schlecht, ein
  #    Stand von vor zwoelf Versionen laesst sich nicht mehr zuverlaessig als
  #    Ganzes zurueckspielen. Was nicht altert, ist der Griff einzelner Dateien
  #    aus dem Tar (configuration.yaml, Automationen, .storage). Danach ist die
  #    Aufbewahrung bemessen, nicht nach "moeglichst lange".
  #
  # Weil der Bucket unversioniert ist, loescht die Expiration direkt. Es entsteht
  # kein Delete-Marker, es braucht also weder NoncurrentVersionExpiration noch
  # ExpiredObjectDeleteMarker zum Nachraeumen.
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
