# Die beiden Offsite-Backup-Buckets. Sie sind bewusst NICHT als aws_s3_bucket
# importiert: es sind die einzigen Kopien von Paperless- und HA-Daten ausserhalb
# des Hauses, und ein importierter Bucket ist per "terraform destroy" oder einem
# geloeschten Resource-Block zerstoerbar. Verwaltet wird hier nur, was diese
# Runde aendern soll, also Versioning und Lifecycle. Public-Access-Block,
# Verschluesselung und Ownership bleiben so, wie sie am Bucket stehen.
#
# Die data-Quellen existieren nur, damit ein falsch geschriebener Bucket-Name
# beim plan auffliegt statt beim apply.

data "aws_s3_bucket" "paperless" {
  bucket = var.paperless_bucket
}

data "aws_s3_bucket" "home_assistant" {
  bucket = var.home_assistant_bucket
}

# ===========================================
# paperless-ngx
# ===========================================

# Versioning ist an diesem Bucket seit jeher aktiv und wird hier nur festgehalten.
resource "aws_s3_bucket_versioning" "paperless" {
  bucket = data.aws_s3_bucket.paperless.id

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
  bucket = data.aws_s3_bucket.paperless.id

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

# Dieser Bucket ist BEWUSST unversioniert, und die Tiefe steht BEWUSST nicht
# hier, sondern in HAs eigener Retention ("behalte N automatische Backups").
#
# Warum keine NoncurrentVersionExpiration als Tiefe: HA zaehlt Kopien, Lifecycle
# zaehlt Tage seit dem Loeschen. Zwei Mechanismen fuer dieselbe Aussage driften
# auseinander, sobald ein Backup-Lauf ausfaellt, und niemand weiss spaeter, welche
# Zahl gewinnt. Wer mehr Staende will, dreht an HA, an einer Stelle.
#
# Warum ueberhaupt kein Versioning: sein einziger Nutzen jenseits von Retention
# ist der Schutz gegen ein Loeschen, das HA nicht gewollt hat. Der greift nur,
# wenn der loeschende Key kein DeleteObjectVersion hat. Aktuell bedienen
# Paperless, HA und das tote raspi5-Skript denselben IAM-Key, und dessen Rechte
# sind ungeprueft (Roadmap Punkt 7, der terraform-homelab-Key kommt nicht an IAM).
# Versioning waere hier also ein Sicherheits-Anstrich ohne Sicherheit.
#
# Es kommt zurueck, wenn der Key pro Konsument getrennt und bucket-scoped ohne
# DeleteObjectVersion ausgestellt ist. Dann als Ransomware-Schutz mit kleinem
# Fenster, ausdruecklich nicht als Retention. Achtung: Versioning wirkt nicht
# rueckwirkend, geschuetzt ist erst, was danach geschrieben wird.
#
# Der weit zurueckliegende Wiederherstellungspunkt kommt stattdessen aus dem
# Monatsarchiv unten.
resource "aws_s3_bucket_lifecycle_configuration" "home_assistant" {
  bucket = data.aws_s3_bucket.home_assistant.id

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
