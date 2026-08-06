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

# Wie tief k3s seine Snapshots haelt, lokal UND in S3. Der Wert gehoert in die
# k3s.service jeder Server-Node, er steuert nichts an der AWS-Seite und steht
# hier, weil er mit den Lifecycle-Regeln zusammen gedacht werden muss.
#
# WARUM NICHT "--etcd-s3-retention": das Secret aus --etcd-s3-config-secret
# kennt diesen Schluessel nicht, und sobald IRGENDEIN weiteres --etcd-s3-*-Flag
# an der Unit steht, ignoriert k3s das Secret komplett und will die Zugangsdaten
# wieder als Flags sehen. Steuerbar bleibt die S3-Tiefe deshalb nur ueber
# --etcd-snapshot-retention, das k3s auf --etcd-s3-retention durchreicht, wenn
# dieses nicht gesetzt ist.
#
# Der Preis: derselbe Wert gilt fuer die lokalen Snapshots auf der Node. 28 sind
# bei zwei Laeufen taeglich 14 Tage. Nach dem Defrag liegt ein Snapshot bei rund
# 16 MB, macht 450 MB je Node. Der Engpass ist k3s-cp-1 mit 30 GB Platte, die
# Raspis haben 117 bzw. 917 GB. Wer den Wert deutlich erhoeht, schaut vorher auf
# cp-1.
variable "etcd_snapshot_retention" {
  description = "Wert fuer --etcd-snapshot-retention in der k3s-Unit, gilt lokal und in S3"
  type        = number
  default     = 28
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
