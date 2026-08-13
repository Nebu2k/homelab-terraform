# One IAM user per backup consumer, each limited to exactly its own bucket.
#
# Naming conventions the bootstrap policy of the Terraform user depends on:
#
#   - The user name starts with "homelab-" and the user has NO path, otherwise
#     that ends up in the ARN and the pattern "user/homelab-*" stops matching.
#   - The policy has path "/homelab/". AttachUserPolicy is tied to the
#     condition ArnLike iam:PolicyARN = ".../policy/homelab/*".
#   - Managed policy instead of aws_iam_user_policy: iam:PutUserPolicy is not
#     granted.
#
# Permissions consistently sit in two statements: the bare bucket ARN for
# s3:ListBucket, the bucket ARN with "/*" for everything at object level.
# ListBucket is an action on the bucket; against a "/*" ARN it comes to
# nothing and returns AccessDenied, even though the policy looks present.
#
# No consumer has s3:DeleteObjectVersion.
#
# The access keys of these users are in iam-access-keys.tf, together with the
# state trade-off they carry.
#
# The bootstrap policy "terraform-homelab-iam" itself does not live in
# Terraform, it was created by hand.
#
# The "description" strings on the aws_iam_policy resources in this file stay
# German on purpose, unlike everything else in this repo. They are ForceNew:
# touching one deletes the policy and recreates it including detach and attach,
# and the IAM user has no permissions for that moment. Translating all of them
# is a 16 add / 16 destroy plan for pure wording. If it ever happens, do it in
# its own apply outside the backup windows.

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
          # The dump goes up as multipart. Without this permission the CLI
          # cannot clean up started parts after an abort and reports a second
          # AccessDenied behind the actual error.
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.teslamate.arn}/*"]
      },
    ]
  })
}

# No DeleteObject: the CronJob never deletes, cleanup happens exclusively
# through the lifecycle rules, and those run on the AWS side without this key.
resource "aws_iam_user_policy_attachment" "teslamate_backup" {
  user       = aws_iam_user.teslamate_backup.name
  policy_arn = aws_iam_policy.teslamate_backup.arn
}

# ===========================================
# paperless-ngx
# ===========================================

# The consumer is the "s3-backup-sync" sidecar in the paperless deployment
# (kubernetes-homelab/manifests/paperless-ngx/deployment.yaml), secret
# "s3-backup-credentials" in the paperless-ngx namespace.
resource "aws_iam_user" "paperless_backup" {
  name = "homelab-paperless-backup"

  tags = {
    Name      = "paperless-offsite-backup"
    ManagedBy = "terraform"
  }
}

# No DeleteObject: the sidecar runs "aws s3 sync" without "--delete".
#
# No restriction to the prefix "paperless-backup/", even though the sidecar
# only writes there. The bucket belongs to this consumer alone.
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
          # For uploading, "s3 sync" needs no GetObject, it compares using the
          # listing metadata. This covers the way back, a restore is an
          # "s3 sync" in the opposite direction.
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

# The consumer is the built-in S3 backup integration of Home Assistant. Its
# key is not in the repo but in the HA configuration on the Longhorn volume and
# is entered through the HA UI. It is the only consumer whose key does not
# reach the cluster through kubeseal.
resource "aws_iam_user" "home_assistant_backup" {
  name = "homelab-home-assistant-backup"

  tags = {
    Name      = "home-assistant-offsite-backup"
    ManagedBy = "terraform"
  }
}

# The only consumer with DeleteObject: Home Assistant runs its own retention
# ("keep N automatic backups") and removes old states from the bucket for it.
#
# Not included: s3:DeleteObjectVersion and s3:GetObjectTagging. The integration
# neither sets nor reads tags.
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
        # ListBucket also covers HeadBucket, which the integration uses at
        # setup time to check that the bucket is reachable.
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
          # The tars are around 490 MB and go up as multipart.
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

# The consumer is the CronJob "ha-backup-archive"
# (kubernetes-homelab/manifests/home-assistant/backup-archive-cronjob.yaml),
# secret "s3-archive-credentials" in the home-assistant namespace. It copies a
# state server-side onto a second key in the same bucket and never deletes.
resource "aws_iam_user" "home_assistant_archive" {
  name = "homelab-home-assistant-archive"

  tags = {
    Name      = "home-assistant-monthly-archive"
    ManagedBy = "terraform"
  }
}

# The cut follows the three API calls of the job:
#
#   list-objects-v2  -> s3:ListBucket   (idempotency check, find the newest tar)
#   copy-object      -> s3:GetObject on the source, s3:PutObject on the target
#   head-object      -> s3:GetObject   (size comparison)
#
# No AbortMultipartUpload: copy-object copies up to 5 GB in one go, there is no
# multipart upload to abort. If an HA tar ever exceeds that size, the job needs
# a multipart copy and this policy the matching permissions.
#
# No GetObjectTagging: the job uses "s3api copy-object --tagging-directive
# REPLACE" and does without.
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

# The consumers are the three CronJobs in kube-system
# (kubernetes-homelab/manifests/etcd-backup/), one per control plane. They read
# the credentials from the secret "etcd-backup-s3" in the same namespace.
resource "aws_iam_user" "etcd_backup" {
  name = "homelab-etcd-backup"

  tags = {
    Name      = "etcd-snapshot-offsite"
    ManagedBy = "terraform"
  }
}

# No DeleteObject: the CronJobs upload with "aws s3 cp" and never delete. The
# depth of the bucket comes from the lifecycle rules alone, and those run on
# the AWS side without this key.
#
# GetObject covers the way back: a restore downloads the snapshot again through
# this key.
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
          # A snapshot is around 55 MB and goes up as multipart.
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
# mealie
# ===========================================

# The consumer is the CronJob "mealie-backup"
# (kubernetes-homelab/manifests/mealie/backup-cronjob.yaml), secret
# "s3-mealie-backup-credentials" in the mealie namespace.
resource "aws_iam_user" "mealie_backup" {
  name = "homelab-mealie-backup"

  tags = {
    Name      = "mealie-offsite-backup"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_policy" "mealie_backup" {
  name        = "mealie-backup"
  path        = "/homelab/"
  description = "Schreibzugriff des Mealie-Backup-CronJobs auf genau seinen Bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.mealie.arn]
      },
      {
        Sid    = "ReadWriteOwnObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.mealie.arn}/*"]
      },
    ]
  })
}

# No DeleteObject: cleanup happens exclusively through the lifecycle rules, and
# those run on the AWS side without this key. The ZIP inside the Mealie pod is
# removed by the job through Mealie's own API, not through S3.
resource "aws_iam_user_policy_attachment" "mealie_backup" {
  user       = aws_iam_user.mealie_backup.name
  policy_arn = aws_iam_policy.mealie_backup.arn
}

# ===========================================
# Freshness probe across all backup buckets
# ===========================================

# The consumer is the CronJob "offsite-backup-freshness"
# (kubernetes-homelab/manifests/backup-monitor/), secret
# "s3-backup-monitor-credentials" in the monitoring namespace. It checks per
# bucket and per prefix whether a sufficiently recent object is there.
#
# It is the only user with access to all backup buckets and at the same time
# the only one allowed to do nothing in them but list.
resource "aws_iam_user" "backup_monitor" {
  name = "homelab-backup-monitor"

  tags = {
    Name      = "offsite-backup-freshness-probe"
    ManagedBy = "terraform"
  }
}

# Only s3:ListBucket. list-objects-v2 returns key, LastModified and size per
# object, which is all the probe needs. Without GetObject a leaked key reveals
# file names and timestamps at most.
#
# "description" on aws_iam_policy is ForceNew: AWS has no call that changes it,
# so Terraform deletes the policy and recreates it including detach and attach.
# The text therefore names no bucket count, so the resource list below can grow
# without removing the policy for a moment.
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
          aws_s3_bucket.mealie.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "backup_monitor" {
  user       = aws_iam_user.backup_monitor.name
  policy_arn = aws_iam_policy.backup_monitor.arn
}
