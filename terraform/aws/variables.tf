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
