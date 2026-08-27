variable "aws_region" {
  description = "AWS region of the backup buckets"
  type        = string
  default     = "eu-central-1"
}

variable "paperless_bucket" {
  description = "Bucket holding the paperless-ngx document_exporter state"
  type        = string
  default     = "homelab-paperless-backup-elmstreet79"
}

# Object Lock is only settable at bucket creation, so this retention cannot be
# introduced later without a new bucket. GOVERNANCE, not COMPLIANCE: a bypass
# stays possible for an admin holding s3:BypassGovernanceRetention.
#
# The clock runs from PutObject, not from the last sync. The sidecar uploads
# only what changed and document_exporter keeps the old mtimes, so a document
# written once is never touched again; a short retention would leave exactly
# the old originals unprotected. Hence a span that outlives them.
variable "paperless_object_lock_days" {
  description = "Default retention every new object in the paperless bucket receives"
  type        = number
  default     = 3650
}

variable "home_assistant_bucket" {
  description = "Bucket holding the Home Assistant backup tars"
  type        = string
  default     = "homelab-homeassistent-elmstreet79"
}

variable "teslamate_bucket" {
  description = "Bucket holding the pg_dump states of the Teslamate database"
  type        = string
  default     = "homelab-teslamate-backup"
}

# Prefix and lifecycle rule belong together, a change happens in exactly this
# place. The keys are assigned by the CronJob in
# kubernetes-homelab/manifests/teslamate/backup-cronjob.yaml.
variable "teslamate_daily_prefix" {
  description = "Key prefix of the daily Teslamate dumps"
  type        = string
  default     = "daily/"
}

variable "teslamate_monthly_prefix" {
  description = "Key prefix of the monthly Teslamate dumps"
  type        = string
  default     = "monthly/"
}

variable "teslamate_daily_days" {
  description = "Retention of the daily Teslamate dumps"
  type        = number
  default     = 30
}

variable "teslamate_monthly_days" {
  description = "Retention of the monthly Teslamate dumps"
  type        = number
  default     = 365
}

variable "teslamate_noncurrent_days" {
  description = "Retention of overwritten Teslamate object versions"
  type        = number
  default     = 30
}

variable "etcd_snapshots_bucket" {
  description = "Bucket holding the etcd snapshots of the three control plane nodes"
  type        = string
  default     = "homelab-etcd-snapshots-elmstreet79"
}

variable "etcd_snapshot_days" {
  description = "Retention of the etcd snapshots in S3"
  type        = number
  default     = 30
}

variable "etcd_snapshot_noncurrent_days" {
  description = "Retention of overwritten etcd snapshot versions"
  type        = number
  default     = 30
}

variable "multipart_abort_days" {
  description = "Age at which aborted multipart uploads are discarded"
  type        = number
  default     = 7
}

variable "home_assistant_archive_days" {
  description = "Retention of the monthly HA archive states"
  type        = number
  default     = 180
}

# The key in the bucket comes from the backup name Home Assistant assigns on
# creation: a manual backup called "Monthly" lands as
# "Monthly_<date>_<time>_<ms>.tar" (+ .metadata.json) in the bucket root. If
# the name changes in the automation, this value has to follow, or the
# lifecycle rule of the monthly archive stops matching.
variable "home_assistant_archive_prefix" {
  description = "Key prefix of the manual monthly HA backups, derived from their backup name"
  type        = string
  default     = "Monthly"
}

variable "mealie_bucket" {
  description = "Bucket holding the ZIPs from Mealie's built-in backup"
  type        = string
  default     = "homelab-mealie-backup"
}

variable "mealie_daily_prefix" {
  description = "Key prefix of the daily Mealie backups"
  type        = string
  default     = "daily/"
}

variable "mealie_monthly_prefix" {
  description = "Key prefix of the monthly Mealie backups"
  type        = string
  default     = "monthly/"
}

variable "mealie_daily_days" {
  description = "Retention of the daily Mealie backups"
  type        = number
  default     = 30
}

variable "mealie_monthly_days" {
  description = "Retention of the monthly Mealie backups"
  type        = number
  default     = 365
}

variable "mealie_noncurrent_days" {
  description = "Retention of overwritten Mealie backups as noncurrent versions"
  type        = number
  default     = 30
}

variable "alerts_topic_name" {
  description = "SNS topic the Alertmanager publishes into"
  type        = string
  default     = "homelab"
}

# If the address changes, Terraform replaces the subscription and the new one
# is unconfirmed. See sns-alerts.tf.
variable "alerts_email" {
  description = "Recipient of the confirmed email subscription on the alert topic"
  type        = string
  default     = "alerts@elmstreet79.de"
}

variable "ses_region" {
  description = "Region of the SES identities, separate from the buckets"
  type        = string
  default     = "eu-west-1"
}

