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
# Teslamate kam als erster Konsument sauber getrennt zur Welt und war die
# Blaupause. Seit 2026-08-05 stehen die drei uebrigen daneben: paperless, Home
# Assistant und der HA-Archiv-Job. Damit hat jeder Konsument seinen eigenen
# User, seine eigene bucket-scoped Policy und seinen eigenen Access Key.
#
# ================== Warum drei und nicht einer ==================
#
# Weil sie unterschiedlich viel duerfen muessen, und das ist der ganze Punkt der
# Trennung. Nur HA braucht DeleteObject, weil es seine Retention selbst faehrt.
# paperless synct ohne "--delete" und der Archiv-Job kopiert nur, beide loeschen
# nie. Ein gemeinsamer Key haette zwangslaeufig das Maximum aller drei gekonnt,
# und genau das war der Ist-Zustand: DeleteObject auf beiden Buckets fuer einen
# Konsumenten, der es nie braucht.
#
# Der zweite Gewinn ist die Rotation. Ein geteilter Key laesst sich nicht
# tauschen, ohne alle Konsumenten gleichzeitig anzufassen, deshalb wurde er neun
# Monate lang nicht getauscht. Drei getrennte Keys rotieren einzeln.
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

# Kein DeleteObject, und das faellt hier nicht schwer: der Sidecar macht
# "aws s3 sync" OHNE "--delete". Er hat also noch nie ein Objekt entfernt, der
# alte geteilte Key trug das Recht nur mit, weil HA es brauchte.
#
# Auch keine Einschraenkung auf das Praefix "paperless-backup/", obwohl der
# Sidecar nur dorthin schreibt. Der Bucket gehoert ausschliesslich diesem
# Konsumenten, eine Praefix-Bedingung wuerde nichts zusaetzlich schuetzen und
# beim ersten Restore in ein anderes Verzeichnis im Weg stehen.
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
          # GetObject braucht "s3 sync" nicht zum Hochladen, es vergleicht ueber
          # die Listing-Metadaten. Es steht hier fuer den Rueckweg: ein Restore
          # ist ein "s3 sync" in die Gegenrichtung, und der soll nicht daran
          # scheitern, dass erst jemand eine Policy anfassen muss.
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

# Konsument ist HAs eingebaute S3-Backup-Integration. Ihr Key steht NICHT im
# Repo, sondern in der HA-Konfiguration auf dem Longhorn-Volume, eingetragen
# ueber die HA-UI. Das ist der einzige der vier Konsumenten, dessen Key nicht
# per kubeseal ins Cluster kommt.
resource "aws_iam_user" "home_assistant_backup" {
  name = "homelab-home-assistant-backup"

  tags = {
    Name      = "home-assistant-offsite-backup"
    ManagedBy = "terraform"
  }
}

# Der EINZIGE Konsument mit DeleteObject, und das ist Absicht statt Nachlaessigkeit:
# HA fuehrt seine Retention selbst ("behalte N automatische Backups") und muss
# dafuer alte Staende aus dem Bucket entfernen. Nimmt man ihm das Recht, laeuft
# der Bucket unbegrenzt voll und niemand merkt es, weil das Hochladen weiter
# klappt.
#
# Was ihm bewusst fehlt, ist s3:DeleteObjectVersion. Das ist die Bedingung, unter
# der Versioning an diesem Bucket ueberhaupt etwas taugt (siehe die lange
# Begruendung in s3-backup-buckets.tf): HAs Loeschen setzt dann nur einen
# Delete-Marker, der eigentliche Stand liegt als noncurrent version darunter und
# ueberlebt einen kompromittierten Cluster.
#
# Ebenfalls nicht drin: s3:GetObjectTagging. HA setzt keine Tags und liest keine.
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
        # ListBucket deckt neben dem Listing auch HeadBucket ab, mit dem die
        # Integration beim Einrichten prueft, ob der Bucket erreichbar ist.
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
          # Die Tars liegen bei rund 490 MB, HA laedt sie als Multipart hoch.
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
# Secret "s3-archive-credentials" im Namespace home-assistant.
#
# Eigener User, obwohl derselbe Bucket: der Job braucht deutlich weniger als HA.
# Er kopiert einen Stand server-seitig auf einen zweiten Key und loescht nie.
# Genau die Archivstaende, die er anlegt, soll ein kompromittierter Cluster ueber
# diesen Key nicht wieder entfernen koennen.
resource "aws_iam_user" "home_assistant_archive" {
  name = "homelab-home-assistant-archive"

  tags = {
    Name      = "home-assistant-monthly-archive"
    ManagedBy = "terraform"
  }
}

# Der Zuschnitt folgt exakt den drei API-Aufrufen des Jobs:
#
#   list-objects-v2  -> s3:ListBucket   (Idempotenz-Pruefung + juengstes Tar suchen)
#   copy-object      -> s3:GetObject auf der Quelle, s3:PutObject auf dem Ziel
#   head-object      -> s3:GetObject   (Groessenvergleich als Gegenprobe)
#
# Kein AbortMultipartUpload: copy-object kopiert in einem Durchgang bis 5 GB, es
# gibt hier keinen Multipart-Upload zum Abbrechen. Waechst ein HA-Tar je
# darueber, braucht der Job einen Multipart-Copy und diese Policy die
# entsprechenden Rechte dazu.
#
# Kein GetObjectTagging, und zwar bewusst: genau daran scheiterte der erste
# Testlauf mit "aws s3 cp". Der Job benutzt seitdem "s3api copy-object
# --tagging-directive REPLACE" und kommt ohne aus. Wer dieses Recht hier
# nachtraegt, macht die Ursache unsichtbar, statt sie zu beheben.
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
# k3s etcd-Snapshots
# ===========================================

# Konsument ist k3s selbst auf den drei Server-Nodes (cp-1, raspi4, raspi5),
# nicht ein Workload im Cluster. Die Zugangsdaten liegen im Secret
# "k3s-etcd-s3-config" im Namespace kube-system, auf das die Units per
# "--etcd-s3-config-secret" zeigen.
#
# Das ist der einzige Konsument, dessen Key NICHT von einem Pod gelesen wird,
# sondern vom k3s-Server-Prozess. Der Umweg ueber ein Secret statt
# "--etcd-s3-access-key" in der Unit ist Absicht: sonst staende der Key im
# Klartext in drei systemd-Units, und jede Rotation waere drei Unit-Edits mit
# Quorum-Check statt eines Commits.
resource "aws_iam_user" "etcd_backup" {
  name = "homelab-etcd-backup"

  tags = {
    Name      = "k3s-etcd-snapshot-offsite"
    ManagedBy = "terraform"
  }
}

# Der zweite Konsument mit DeleteObject, nach Home Assistant, und aus demselben
# Grund: k3s fuehrt seine Snapshot-Retention selbst und raeumt aeltere Staende
# aus dem Bucket.
#
# Erst war geplant, ihm das Loeschen zu verwehren und die Tiefe rein ueber
# Lifecycle zu machen. Das geht hier NICHT, und der Grund ist eine Eigenheit von
# --etcd-s3-config-secret: das Secret kennt keinen Retention-Schluessel, und
# sobald ein weiteres --etcd-s3-*-Flag an der Unit steht, ignoriert k3s das
# Secret vollstaendig und will die Zugangsdaten wieder im Klartext als Flags.
# Die S3-Tiefe haengt damit an --etcd-snapshot-retention, und das gilt zugleich
# lokal. Ein unerreichbar hoher Wert haette die Node-Platten volllaufen lassen,
# der Engpass ist cp-1 mit 30 GB.
#
# Was den Verzicht traegt: DeleteObjectVersion fehlt, und der Bucket ist
# versioniert. k3s' Loeschen setzt damit nur einen Delete-Marker, der Snapshot
# liegt als noncurrent version darunter weiter und ueberlebt
# etcd_snapshot_noncurrent_days. Ein kompromittierter Cluster kann die Staende
# also unsichtbar machen, aber nicht vernichten. Das ist exakt die Bedingung,
# unter der Versioning am HA-Bucket ueberhaupt etwas taugt.
#
# GetObject ist drin, obwohl der Schreibpfad es nicht braucht. k3s listet und
# liest beim Start seine S3-Snapshots, um die ConfigMap k3s-etcd-snapshots zu
# fuellen, und der Restore-Weg ("k3s server --cluster-reset
# --etcd-s3 --cluster-reset-restore-path=...") laedt den Snapshot ueber genau
# diesen Key wieder herunter. Ohne GetObject steht man im Ernstfall vor einem
# vollen Bucket, den man erst per Konsole aufmachen muss.
resource "aws_iam_policy" "etcd_backup" {
  name        = "etcd-backup"
  path        = "/homelab/"
  description = "Schreib- und Lesezugriff der k3s-Server-Nodes auf den etcd-Snapshot-Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListOwnBucket"
        Effect = "Allow"
        # Nackter Bucket-ARN. k3s listet den Bucket bei jedem Snapshot-Lauf, um
        # seine Retention zu bestimmen, und beim Start fuer die ConfigMap.
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.etcd_snapshots.arn]
      },
      {
        Sid    = "ReadWriteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          # Fuer k3s' eigene Retention, siehe oben. KEIN DeleteObjectVersion,
          # das ist die Bedingung, unter der das vertretbar ist.
          "s3:DeleteObject",
          # Ein Snapshot liegt nach dem Defrag bei rund 16 MB und geht als
          # Multipart hoch.
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
# "s3-backup-monitor-credentials" im Namespace monitoring.
#
# Er beantwortet die eine Frage, die die Job-Alerts NICHT beantworten koennen:
# ist im Bucket wirklich etwas angekommen. Ein erfolgreicher CronJob beweist das
# nicht. Bei paperless klafft die Luecke am weitesten, weil der Upload im
# Sidecar auf eigenem Timer laeuft und ein Fehlschlag dort nur eine Zeile ins
# Log schreibt, und bei HA gibt es ueberhaupt keinen Job, den man beobachten
# koennte.
#
# Deshalb hat dieser User als einziger Zugriff auf ALLE Buckets, und deshalb
# darf er als einziger gar nichts damit tun ausser sie aufzulisten.
#
# Seit dem etcd-Bucket sind es vier. Gerade dort ist die Sonde der einzige
# Beleg: k3s laedt seine Snapshots im Server-Prozess hoch, es gibt keinen
# CronJob und keinen Pod-Status, an dem ein Fehlschlag sichtbar waere, sondern
# nur eine Zeile im journal auf der jeweiligen Node.
resource "aws_iam_user" "backup_monitor" {
  name = "homelab-backup-monitor"

  tags = {
    Name      = "offsite-backup-freshness-probe"
    ManagedBy = "terraform"
  }
}

# NUR s3:ListBucket, und das reicht exakt aus: list-objects-v2 liefert Key,
# LastModified und Size je Objekt, und mehr braucht die Sonde nicht. Kein
# GetObject, der Inhalt der Backups geht sie nichts an. Ein geleakter Key
# verraet damit hoechstens Dateinamen und Zeitstempel, und die Dateinamen des
# paperless-Exports tragen Titel und Korrespondent.
#
# Das ist der Grund fuer den eigenen User statt eines Rechts an einem
# bestehenden: kein Konsument darf in die Buckets der anderen sehen, und die
# Sonde muss in alle drei sehen. Genau eine Richtung dieser Kreuzung ist
# harmlos, naemlich diese.
# FALLE, hier einmal teuer bezahlt: "description" an aws_iam_policy ist ForceNew.
# AWS kennt keinen Aufruf, der die Beschreibung einer Policy aendert, Terraform
# loescht sie also und legt sie neu an, inklusive Detach und Attach. Genau das
# passierte beim Hinzufuegen des vierten Buckets, weil in der Beschreibung
# "drei Backup-Buckets" stand.
#
# Die Beschreibungen hier zaehlen deshalb nichts mehr. Die Resource-Liste unten
# darf wachsen, ohne dass die Policy dabei durch ein Loch laeuft, in dem die
# Sonde keine Rechte hat.
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
        # Nackte Bucket-ARNs, kein "/*": ListBucket ist eine Aktion auf dem
        # Bucket. Mit "/*" liefe sie still ins Leere und die Sonde bekaeme
        # AccessDenied, obwohl die Policy vorhanden aussieht.
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
