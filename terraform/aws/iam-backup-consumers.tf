# Ein IAM-User je Backup-Konsument, bucket-scoped und schreibend-lesend.
#
# ================== Ausgangslage, gemessen am 2026-08-05 ==================
#
# Bis hierher bedienen Paperless, Home Assistant und der HA-Archiv-CronJob EINEN
# gemeinsamen User "homelab-backup" (Key AKIARECCIKPIYMCUEK54, angelegt am
# 2025-11-06, nie rotiert). Dessen Policy "homelab-backup-policy" v6 gewaehrt in
# einem einzigen Statement PutObject, GetObject, DeleteObject und ListBucket auf
# beide Buckets. Zwei Befunde daraus, die hier direkt einfliessen:
#
# 1. DeleteObjectVersion ist NICHT enthalten. Versioning traegt in diesem Account
#    also wirklich gegen einen kompromittierten Cluster und ist kein Anstrich.
#    Deshalb steht es am Teslamate-Bucket an.
# 2. Die Resource-Liste enthaelt "arn:aws:s3:::homelab-homeassistent-elmstreet79*"
#    mit angehaengtem Stern statt "/*". Das trifft die Objekte zwar mit, aber
#    eben auch jeden anderen Bucket, dessen Name so beginnt. Bucket-Namen sind
#    global eindeutig und von jedem registrierbar. Hier deshalb konsequent die
#    zweizeilige Form: Bucket-ARN fuer ListBucket, Bucket-ARN + "/*" fuer alles
#    auf Objektebene.
#
# Diese Datei ist der Anfang der Abloesung. Teslamate kommt als erster
# Konsument sauber getrennt zur Welt und ist die Blaupause fuer den Rest
# (Roadmap Punkt 4: eigene User fuer Paperless, HA und Archiv-Job, danach
# homelab-backup abschalten).
#
# ================== Was hier bewusst NICHT steht ==================
#
# Es gibt KEINE aws_iam_access_key-Ressource. Das Secret Access Key landete
# sonst im Terraform-State und der State-Bucket waere ab da ein
# Credential-Speicher. Der Key wird einmal in der Konsole erzeugt und per
# kubeseal ins Cluster gebracht.
#
# Das ist gleichzeitig die Sicherung der Bootstrap-Policy: der Terraform-User
# darf User unter "homelab-*" anlegen und Policies unter "/homelab/*" anhaengen,
# aber kein iam:CreateAccessKey. Er kann sich also keine benutzbaren
# Zugangsdaten bauen, auch nicht ueber den Umweg eines neuen Users. Wer
# aws_iam_access_key hier nachtraegt, macht diese Eigenschaft kaputt und bekommt
# ausserdem beim apply ein AccessDenied.
#
# Die Bootstrap-Policy "terraform-homelab-iam" selbst ist bewusst NICHT in
# Terraform. Terraform kann sich seine eigenen Rechte nicht selbst erteilen,
# das ist dieselbe Kategorie wie der State-Bucket: von Hand angelegt, im Skill
# dokumentiert.

# ===========================================
# teslamate
# ===========================================

# Der Name MUSS mit "homelab-" beginnen, sonst greift die Bootstrap-Policy
# nicht (Resource "arn:aws:iam::...:user/homelab-*"). Und der User bekommt
# KEINEN path, sonst wandert der in den ARN und das Muster passt nicht mehr.
resource "aws_iam_user" "teslamate_backup" {
  name = "homelab-teslamate-backup"

  tags = {
    Name      = "teslamate-offsite-backup"
    ManagedBy = "terraform"
  }
}

# path "/homelab/" ist Pflicht: die Bootstrap-Policy erlaubt AttachUserPolicy
# nur unter der Bedingung ArnLike iam:PolicyARN = ".../policy/homelab/*".
# Ebenso Pflicht ist die Managed Policy statt aws_iam_user_policy (inline):
# iam:PutUserPolicy ist bewusst nicht gewaehrt.
resource "aws_iam_policy" "teslamate_backup" {
  name        = "teslamate-backup"
  path        = "/homelab/"
  description = "Schreibzugriff des Teslamate-Backup-CronJobs auf genau seinen Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListOwnBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        # ListBucket ist eine Aktion AUF dem Bucket, nicht auf Objekten. Sie
        # gehoert an den nackten Bucket-ARN, ein "/*" hier laesst sie still
        # ins Leere laufen.
        Resource = [aws_s3_bucket.teslamate.arn]
      },
      {
        Sid    = "ReadWriteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          # Der Dump geht als Multipart hoch. Scheitert er mittendrin, will die
          # CLI die angefangenen Teile selbst abraeumen. Ohne dieses Recht
          # kaeme dabei ein zweites, irrefuehrendes AccessDenied hinterher, das
          # den eigentlichen Fehler im Log verdeckt.
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.teslamate.arn}/*"]
      },
    ]
  })
}

# ACHTUNG, kein DeleteObject und kein DeleteObjectVersion, und das ist kein
# Versehen: der CronJob loescht nie. Aufgeraeumt wird ausschliesslich durch die
# Lifecycle-Regeln, und die laufen AWS-seitig ohne diesen Key. Damit kann ein
# kompromittierter Cluster keinen einzigen Backup-Stand entfernen.
resource "aws_iam_user_policy_attachment" "teslamate_backup" {
  user       = aws_iam_user.teslamate_backup.name
  policy_arn = aws_iam_policy.teslamate_backup.arn
}
