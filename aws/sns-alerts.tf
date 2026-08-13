# The alert path of the homelab: the Alertmanager in the cluster publishes
# into this topic, SNS delivers by mail. It is the only path, Gatus and Grafana
# deliberately do not alert on their own.
#
# Topic and subscription are older than this stack and were imported:
#
#   terraform import aws_sns_topic.alerts <topic-arn>
#   terraform import aws_sns_topic_subscription.alerts_email <subscription-arn>
#
# The bootstrap policy "terraform-homelab-iam" (maintained by hand, see
# iam-backup-consumers.tf) needs SNS permissions for this. Without them even
# the plan fails with AuthorizationError on GetTopicAttributes.

resource "aws_sns_topic" "alerts" {
  name = var.alerts_topic_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "homelab-alerts"
    ManagedBy = "terraform"
  }
}

# An email subscription starts out as "PendingConfirmation" and only becomes
# active once someone clicks the link in the confirmation mail. Terraform
# cannot wait for that, and cannot delete an unconfirmed one either, it only
# drops it from the state. This one is confirmed and imported.
#
# "endpoint" is ForceNew: a changed address replaces the subscription with an
# unconfirmed one. Until it is confirmed, alerts go nowhere without anything
# failing anywhere. Hence prevent_destroy, a change here should trip the plan
# rather than run through.
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alerts_email

  lifecycle {
    prevent_destroy = true
  }
}

# The consumer is the Alertmanager (kubernetes-homelab/manifests/
# kube-prometheus-stack/values.yaml), secret "alertmanager-aws-credentials" in
# the monitoring namespace. Its access key is in iam-access-keys.tf, next to
# those of the backup consumers.
resource "aws_iam_user" "alertmanager" {
  name = "homelab-alertmanager"

  tags = {
    Name      = "alertmanager-sns-publisher"
    ManagedBy = "terraform"
  }
}

# Only sns:Publish on exactly this topic. The Alertmanager subscribes to
# nothing and reads nothing back.
resource "aws_iam_policy" "alertmanager_sns" {
  name        = "alertmanager-sns"
  path        = "/homelab/"
  description = "Publish-Recht des Alertmanagers auf das Alarm-Topic"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PublishToAlertTopic"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.alerts.arn]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "alertmanager_sns" {
  user       = aws_iam_user.alertmanager.name
  policy_arn = aws_iam_policy.alertmanager_sns.arn
}
