# Ein IAM-User je Backup-Konsument, jeweils auf genau seinen Bucket begrenzt.
#
# Namenskonventionen, die die Bootstrap-Policy des Terraform-Users voraussetzt:
#
#   - Der User-Name beginnt mit "homelab-" und der User hat KEINEN path, sonst
#     wandert der in den ARN und das Muster "user/homelab-*" passt nicht mehr.
#   - Die Policy hat path "/homelab/". AttachUserPolicy ist an die Bedingung
#     ArnLike iam:PolicyARN = ".../policy/homelab/*" geknuepft.
#   - Managed Policy statt aws_iam_user_policy: iam:PutUserPolicy ist nicht
#     gewaehrt.
#
# Rechte stehen konsequent in zwei Statements: der nackte Bucket-ARN fuer
# s3:ListBucket, der Bucket-ARN mit "/*" fuer alles auf Objektebene. ListBucket
# ist eine Aktion auf dem Bucket; an einem "/*"-ARN laeuft sie ins Leere und
# liefert AccessDenied, obwohl die Policy vorhanden aussieht.
#
# Kein Konsument hat s3:DeleteObjectVersion.
#
# Es gibt hier KEINE aws_iam_access_key-Ressource. Das Secret Access Key laege
# sonst im Terraform-State. Die Keys entstehen in der AWS-Konsole und kommen per
# kubeseal ins Cluster. Der Terraform-User hat kein iam:CreateAccessKey, ein
# nachtraeglich eingefuegter aws_iam_access_key scheitert im apply mit
# AccessDenied.
#
# Die Bootstrap-Policy "terraform-homelab-iam" selbst liegt nicht in Terraform,
# sie ist von Hand angelegt.

# ===========================================
# teslamate
# ===========================================

resource "aws_iam_user" "teslamate_backup" {
  name = "homelab-teslamate-backup"

  tags = {
    Name      = "teslamate-offsite-backup"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_policy" "teslamate_backup" {
  name        = "teslamate-backup"
  path        = "/homelab/"
  description = "Schreibzugriff des Teslamate-Backup-CronJobs auf genau seinen Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.teslamate.arn]
      },
      {
        Sid    = "ReadWriteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          # Der Dump geht als Multipart hoch. Ohne dieses Recht kann die CLI
          # angefangene Teile nach einem Abbruch nicht selbst abraeumen und
          # meldet ein zweites AccessDenied hinter dem eigentlichen Fehler.
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.teslamate.arn}/*"]
      },
    ]
  })
}

# Kein DeleteObject: der CronJob loescht nie, aufgeraeumt wird ausschliesslich
# durch die Lifecycle-Regeln, und die laufen AWS-seitig ohne diesen Key.
resource "aws_iam_user_policy_attachment" "teslamate_backup" {
  user       = aws_iam_user.teslamate_backup.name
  policy_arn = aws_iam_policy.teslamate_backup.arn
}

# ===========================================
# paperless-ngx
# ===========================================

# Konsument ist der Sidecar "s3-backup-sync" im paperless-Deployment
# (kubernetes-homelab/manifests/paperless-ngx/deployment.yaml), Secret
# "s3-backup-credentials" im Namespace paperless-ngx.
resource "aws_iam_user" "paperless_backup" {
  name = "homelab-paperless-backup"

  tags = {
    Name      = "paperless-offsite-backup"
    ManagedBy = "terraform"
  }
}

# Kein DeleteObject: der Sidecar macht "aws s3 sync" ohne "--delete".
#
# Keine Einschraenkung auf das Praefix "paperless-backup/", obwohl der Sidecar
# nur dorthin schreibt. Der Bucket gehoert ausschliesslich diesem Konsumenten.
resource "aws_iam_policy" "paperless_backup" {
  name        = "paperless-backup"
  path        = "/homelab/"
  description = "Schreibzugriff des paperless-Export-Sidecars auf genau seinen Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.paperless.arn]
      },
      {
        Sid    = "ReadWriteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          # Zum Hochladen braucht "s3 sync" kein GetObject, es vergleicht ueber
          # die Listing-Metadaten. Es deckt den Rueckweg ab, ein Restore ist ein
          # "s3 sync" in die Gegenrichtung.
          "s3:GetObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.paperless.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "paperless_backup" {
  user       = aws_iam_user.paperless_backup.name
  policy_arn = aws_iam_policy.paperless_backup.arn
}

# ===========================================
# Home Assistant (die Instanz selbst)
# ===========================================

# Konsument ist die eingebaute S3-Backup-Integration von Home Assistant. Ihr Key
# steht nicht im Repo, sondern in der HA-Konfiguration auf dem Longhorn-Volume
# und wird ueber die HA-UI eingetragen. Es ist der einzige der Konsumenten,
# dessen Key nicht per kubeseal ins Cluster kommt.
resource "aws_iam_user" "home_assistant_backup" {
  name = "homelab-home-assistant-backup"

  tags = {
    Name      = "home-assistant-offsite-backup"
    ManagedBy = "terraform"
  }
}

# Der einzige Konsument mit DeleteObject: Home Assistant fuehrt seine Retention
# selbst ("behalte N automatische Backups") und entfernt dafuer alte Staende aus
# dem Bucket.
#
# Nicht enthalten: s3:DeleteObjectVersion und s3:GetObjectTagging. Die
# Integration setzt und liest keine Tags.
resource "aws_iam_policy" "home_assistant_backup" {
  name        = "home-assistant-backup"
  path        = "/homelab/"
  description = "Zugriff der HA-eigenen S3-Backup-Integration, inkl. Delete fuer HAs eigene Retention"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListOwnBucket"
        Effect = "Allow"
        # ListBucket deckt auch HeadBucket ab, mit dem die Integration beim
        # Einrichten die Erreichbarkeit des Buckets prueft.
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.home_assistant.arn]
      },
      {
        Sid    = "ReadWriteDeleteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          # Die Tars liegen bei rund 490 MB und gehen als Multipart hoch.
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.home_assistant.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "home_assistant_backup" {
  user       = aws_iam_user.home_assistant_backup.name
  policy_arn = aws_iam_policy.home_assistant_backup.arn
}

# ===========================================
# Home Assistant, Monatsarchiv
# ===========================================

# Konsument ist der CronJob "ha-backup-archive"
# (kubernetes-homelab/manifests/home-assistant/backup-archive-cronjob.yaml),
# Secret "s3-archive-credentials" im Namespace home-assistant. Er kopiert einen
# Stand server-seitig auf einen zweiten Key im selben Bucket und loescht nie.
resource "aws_iam_user" "home_assistant_archive" {
  name = "homelab-home-assistant-archive"

  tags = {
    Name      = "home-assistant-monthly-archive"
    ManagedBy = "terraform"
  }
}

# Der Zuschnitt folgt den drei API-Aufrufen des Jobs:
#
#   list-objects-v2  -> s3:ListBucket   (Idempotenz-Pruefung, juengstes Tar suchen)
#   copy-object      -> s3:GetObject auf der Quelle, s3:PutObject auf dem Ziel
#   head-object      -> s3:GetObject   (Groessenvergleich)
#
# Kein AbortMultipartUpload: copy-object kopiert bis 5 GB in einem Durchgang, es
# gibt keinen Multipart-Upload zum Abbrechen. Ueberschreitet ein HA-Tar diese
# Groesse, braucht der Job einen Multipart-Copy und diese Policy die passenden
# Rechte.
#
# Kein GetObjectTagging: der Job benutzt "s3api copy-object --tagging-directive
# REPLACE" und kommt ohne aus.
resource "aws_iam_policy" "home_assistant_archive" {
  name        = "home-assistant-archive"
  path        = "/homelab/"
  description = "Kopierrechte des HA-Monatsarchiv-CronJobs innerhalb des HA-Buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.home_assistant.arn]
      },
      {
        Sid    = "CopyWithinOwnBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = ["${aws_s3_bucket.home_assistant.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "home_assistant_archive" {
  user       = aws_iam_user.home_assistant_archive.name
  policy_arn = aws_iam_policy.home_assistant_archive.arn
}

# ===========================================
# etcd-Snapshots
# ===========================================

# Konsumenten sind die drei CronJobs in kube-system
# (kubernetes-homelab/manifests/etcd-backup/), je einer pro Control-Plane. Sie
# lesen die Zugangsdaten aus dem Secret "etcd-backup-s3" im selben Namespace.
resource "aws_iam_user" "etcd_backup" {
  name = "homelab-etcd-backup"

  tags = {
    Name      = "etcd-snapshot-offsite"
    ManagedBy = "terraform"
  }
}

# Kein DeleteObject: die CronJobs laden per "aws s3 cp" hoch und loeschen nie.
# Die Tiefe des Buckets kommt allein aus den Lifecycle-Regeln, und die laufen
# AWS-seitig ohne diesen Key.
#
# GetObject deckt den Rueckweg ab: ein Restore laedt den Snapshot ueber diesen
# Key wieder herunter.
resource "aws_iam_policy" "etcd_backup" {
  name        = "etcd-backup"
  path        = "/homelab/"
  description = "Schreib- und Lesezugriff der etcd-Snapshot-CronJobs auf ihren Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.etcd_snapshots.arn]
      },
      {
        Sid    = "ReadWriteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          # Ein Snapshot liegt bei rund 55 MB und geht als Multipart hoch.
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.etcd_snapshots.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "etcd_backup" {
  user       = aws_iam_user.etcd_backup.name
  policy_arn = aws_iam_policy.etcd_backup.arn
}

# ===========================================
# Frische-Sonde ueber alle vier Buckets
# ===========================================

# Konsument ist der CronJob "offsite-backup-freshness"
# (kubernetes-homelab/manifests/backup-monitor/), Secret
# "s3-backup-monitor-credentials" im Namespace monitoring. Er prueft je Bucket
# und je Praefix, ob dort ein hinreichend junges Objekt liegt.
#
# Es ist der einzige User mit Zugriff auf alle vier Buckets und zugleich der
# einzige, der darin nichts tun darf ausser aufzulisten.
resource "aws_iam_user" "backup_monitor" {
  name = "homelab-backup-monitor"

  tags = {
    Name      = "offsite-backup-freshness-probe"
    ManagedBy = "terraform"
  }
}

# Nur s3:ListBucket. list-objects-v2 liefert Key, LastModified und Size je
# Objekt, mehr braucht die Sonde nicht. Ohne GetObject verraet ein geleakter Key
# hoechstens Dateinamen und Zeitstempel.
#
# "description" an aws_iam_policy ist ForceNew: AWS kennt keinen Aufruf, der sie
# aendert, Terraform loescht die Policy und legt sie samt Detach und Attach neu
# an. Der Text nennt deshalb keine Bucket-Anzahl, damit die Resource-Liste unten
# wachsen kann, ohne die Policy kurzzeitig zu entfernen.
resource "aws_iam_policy" "backup_monitor" {
  name        = "backup-monitor"
  path        = "/homelab/"
  description = "Nur-Listing ueber die Offsite-Backup-Buckets fuer die Frische-Sonde"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAllBackupBuckets"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [
          aws_s3_bucket.paperless.arn,
          aws_s3_bucket.home_assistant.arn,
          aws_s3_bucket.teslamate.arn,
          aws_s3_bucket.etcd_snapshots.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "backup_monitor" {
  user       = aws_iam_user.backup_monitor.name
  policy_arn = aws_iam_policy.backup_monitor.arn
}
