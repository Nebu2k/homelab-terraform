# The access keys of the eight homelab consumers, in one file rather than next
# to each user: a rotation is one operation across all of them, and the
# trade-off below only has to be said once.
#
# Both halves of every key land in the Terraform state, and the state bucket is
# versioned, so a rotation never removes the old secret from the bucket, it only
# stops the current version from naming it. That is the price. What it buys is a
# single place that says which key is current and which consumer it belongs to;
# the keys created in the console had no such record and could only be told
# apart by their creation date.
#
# The bootstrap policy "terraform-homelab-iam" (maintained by hand, see
# iam-backup-consumers.tf) covers CreateAccessKey, DeleteAccessKey and
# UpdateAccessKey on user/homelab-*.
#
# Rotating one consumer:
#
#   terraform apply -replace=aws_iam_access_key.mealie_backup
#   terraform output -json backup_consumer_secrets
#
# The replace deletes the old key in the same apply, so the consumer is without
# a valid key until its secret is resealed. All of them are CronJobs or a
# sidecar that retries, so a gap of minutes costs a single run at most. Do not
# stack it with a backup window.
#
# Seven of the eight secrets reach the cluster through kubeseal, the
# home_assistant_backup key is typed into the Home Assistant UI by hand.

resource "aws_iam_access_key" "teslamate_backup" {
  user = aws_iam_user.teslamate_backup.name
}

resource "aws_iam_access_key" "paperless_backup" {
  user = aws_iam_user.paperless_backup.name
}

resource "aws_iam_access_key" "home_assistant_backup" {
  user = aws_iam_user.home_assistant_backup.name
}

resource "aws_iam_access_key" "home_assistant_archive" {
  user = aws_iam_user.home_assistant_archive.name
}

resource "aws_iam_access_key" "etcd_backup" {
  user = aws_iam_user.etcd_backup.name
}

resource "aws_iam_access_key" "mealie_backup" {
  user = aws_iam_user.mealie_backup.name
}

resource "aws_iam_access_key" "backup_monitor" {
  user = aws_iam_user.backup_monitor.name
}

resource "aws_iam_access_key" "alertmanager" {
  user = aws_iam_user.alertmanager.name
}
