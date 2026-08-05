variable "aws_region" {
  description = "AWS region der Backup-Buckets"
  type        = string
  default     = "eu-central-1"
}

variable "paperless_bucket" {
  description = "Bucket mit dem paperless-ngx document_exporter-Stand"
  type        = string
  default     = "homelab-paperless-backup"
}

variable "home_assistant_bucket" {
  description = "Bucket mit den Home-Assistant-Backup-Tars"
  type        = string
  default     = "homelab-homeassistent-elmstreet79"
}

variable "teslamate_bucket" {
  description = "Bucket mit den pg_dump-Staenden der Teslamate-Datenbank"
  type        = string
  default     = "homelab-teslamate-backup"
}

# Praefixe der beiden Teslamate-Ablagen. Anders als beim HA-Monatsarchiv haengen
# sie NICHT an einem fremden Namensschema: den Key vergibt unser eigener CronJob.
# Trotzdem als Variable, weil Praefix und Lifecycle-Regel zusammengehoeren und
# eine Aenderung an genau einer Stelle passieren soll. Der CronJob liegt in
# kubernetes-homelab/manifests/teslamate/backup-cronjob.yaml.
variable "teslamate_daily_prefix" {
  description = "Key-Praefix der taeglichen Teslamate-Dumps"
  type        = string
  default     = "daily/"
}

variable "teslamate_monthly_prefix" {
  description = "Key-Praefix der monatlichen Teslamate-Dumps"
  type        = string
  default     = "monthly/"
}

variable "teslamate_daily_days" {
  description = "Aufbewahrung der taeglichen Teslamate-Dumps"
  type        = number
  default     = 30
}

variable "teslamate_monthly_days" {
  description = "Aufbewahrung der monatlichen Teslamate-Dumps"
  type        = number
  default     = 365
}

variable "teslamate_noncurrent_days" {
  description = "Aufbewahrung ueberschriebener Teslamate-Objektversionen (Ransomware-Fenster)"
  type        = number
  default     = 30
}

variable "etcd_snapshots_bucket" {
  description = "Bucket mit den etcd-Snapshots der drei k3s-Server-Nodes"
  type        = string
  default     = "homelab-etcd-snapshots-elmstreet79"
}

variable "etcd_snapshot_days" {
  description = "Aufbewahrung der etcd-Snapshots in S3"
  type        = number
  default     = 30
}

variable "etcd_snapshot_noncurrent_days" {
  description = "Aufbewahrung ueberschriebener etcd-Snapshot-Versionen (Ransomware-Fenster)"
  type        = number
  default     = 30
}

# k3s hat mit "--etcd-s3-retention" eine eigene Retention und loescht darueber
# hinausgehende Snapshots selbst aus dem Bucket. Das soll es hier NICHT tun,
# aufgeraeumt wird per Lifecycle, damit der IAM-User ohne DeleteObject auskommt.
#
# Der Wert ist deshalb bewusst unerreichbar hoch gewaehlt: 3 Server-Nodes mal 2
# Snapshots taeglich mal etcd_snapshot_days sind rund 180 Objekte, und mehr
# werden es nie, weil die Lifecycle-Regel am anderen Ende abraeumt. k3s kommt
# nie an seine Schwelle und versucht nie zu loeschen.
#
# Diese Variable steuert NICHTS an der AWS-Seite. Sie steht hier, weil der Wert
# in die k3s-Unit auf allen drei Nodes gehoert und die Begruendung dafuer an
# derselben Stelle stehen soll wie die Lifecycle-Regel, gegen die sie sich
# richtet. Wer sie senkt, muss dem User DeleteObject geben.
variable "etcd_s3_retention" {
  description = "Wert fuer --etcd-s3-retention in der k3s-Unit, absichtlich unerreichbar hoch"
  type        = number
  default     = 1000
}

variable "multipart_abort_days" {
  description = "Alter, ab dem abgebrochene Multipart-Uploads verworfen werden"
  type        = number
  default     = 7
}

variable "home_assistant_archive_days" {
  description = "Aufbewahrung der monatlichen HA-Archivstaende"
  type        = number
  default     = 180
}

# Der Key im Bucket entsteht aus dem Backup-Namen, den HA beim Erstellen bekommt.
# Belegt am 2026-08-05: ein manuelles Backup namens "Monthly" landet als
# "Monthly_2026-08-05_04.41_39949402.tar" (+ .metadata.json) im Bucket-Root.
# Aendert sich der Name in der Automation, MUSS dieser Wert mitgehen, sonst
# sammeln sich Archivstaende an, die keine Regel je aufraeumt.
variable "home_assistant_archive_prefix" {
  description = "Key-Praefix der manuellen HA-Monatsbackups, entsteht aus deren Backup-Namen"
  type        = string
  default     = "Monthly"
}
