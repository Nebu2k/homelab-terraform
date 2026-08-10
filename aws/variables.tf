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

# Praefix und Lifecycle-Regel gehoeren zusammen, eine Aenderung passiert an
# genau dieser Stelle. Die Keys vergibt der CronJob in
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
  description = "Aufbewahrung ueberschriebener Teslamate-Objektversionen"
  type        = number
  default     = 30
}

variable "etcd_snapshots_bucket" {
  description = "Bucket mit den etcd-Snapshots der drei Control-Plane-Nodes"
  type        = string
  default     = "homelab-etcd-snapshots-elmstreet79"
}

variable "etcd_snapshot_days" {
  description = "Aufbewahrung der etcd-Snapshots in S3"
  type        = number
  default     = 30
}

variable "etcd_snapshot_noncurrent_days" {
  description = "Aufbewahrung ueberschriebener etcd-Snapshot-Versionen"
  type        = number
  default     = 30
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

# Der Key im Bucket entsteht aus dem Backup-Namen, den Home Assistant beim
# Erstellen vergibt: ein manuelles Backup namens "Monthly" landet als
# "Monthly_<Datum>_<Zeit>_<ms>.tar" (+ .metadata.json) im Bucket-Root. Aendert
# sich der Name in der Automation, muss dieser Wert mitgehen, sonst greift die
# Lifecycle-Regel des Monatsarchivs nicht mehr.
variable "home_assistant_archive_prefix" {
  description = "Key-Praefix der manuellen HA-Monatsbackups, entsteht aus deren Backup-Namen"
  type        = string
  default     = "Monthly"
}

variable "mealie_bucket" {
  description = "Bucket mit den ZIPs aus Mealies eingebautem Backup"
  type        = string
  default     = "homelab-mealie-backup"
}

variable "mealie_daily_prefix" {
  description = "Key-Praefix der taeglichen Mealie-Backups"
  type        = string
  default     = "daily/"
}

variable "mealie_monthly_prefix" {
  description = "Key-Praefix der monatlichen Mealie-Backups"
  type        = string
  default     = "monthly/"
}

variable "mealie_daily_days" {
  description = "Aufbewahrung der taeglichen Mealie-Backups"
  type        = number
  default     = 30
}

variable "mealie_monthly_days" {
  description = "Aufbewahrung der monatlichen Mealie-Backups"
  type        = number
  default     = 365
}

variable "mealie_noncurrent_days" {
  description = "Aufbewahrung ueberschriebener Mealie-Backups als noncurrent version"
  type        = number
  default     = 30
}

variable "alerts_topic_name" {
  description = "SNS-Topic, in das der Alertmanager publisht"
  type        = string
  default     = "homelab"
}

# Aendert sich die Adresse, ersetzt Terraform die Subscription und die neue ist
# unbestaetigt. Siehe sns-alerts.tf.
variable "alerts_email" {
  description = "Empfaenger der bestaetigten email-Subscription am Alarm-Topic"
  type        = string
  default     = "alerts@elmstreet79.de"
}
