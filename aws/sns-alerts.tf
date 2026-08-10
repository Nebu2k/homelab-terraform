# Der Alarmweg des Homelabs: der Alertmanager im Cluster publisht in dieses
# Topic, SNS stellt per Mail zu. Es ist der einzige Weg, Gatus und Grafana
# alarmieren bewusst nicht selbst.
#
# Topic und Subscription sind aelter als dieser Stack und wurden importiert:
#
#   terraform import aws_sns_topic.alerts <topic-arn>
#   terraform import aws_sns_topic_subscription.alerts_email <subscription-arn>
#
# Die Bootstrap-Policy "terraform-homelab-iam" (von Hand gepflegt, siehe
# iam-backup-consumers.tf) braucht dafuer SNS-Rechte. Fehlen sie, scheitert
# schon der plan mit AuthorizationError bei GetTopicAttributes.

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

# Eine email-Subscription entsteht als "PendingConfirmation" und wird erst
# aktiv, wenn jemand den Link in der Bestaetigungsmail klickt. Terraform kann
# darauf nicht warten und eine unbestaetigte auch nicht wieder loeschen, es
# nimmt sie dann nur aus dem State. Diese hier ist bestaetigt und importiert.
#
# "endpoint" ist ForceNew: eine geaenderte Adresse ersetzt die Subscription
# durch eine unbestaetigte. Bis zur Bestaetigung laufen Alarme ins Leere, ohne
# dass irgendwo etwas fehlschlaegt. Deshalb prevent_destroy, eine Aenderung
# hier soll im plan anschlagen statt durchzulaufen.
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alerts_email

  lifecycle {
    prevent_destroy = true
  }
}

# Konsument ist der Alertmanager (kubernetes-homelab/manifests/
# kube-prometheus-stack/values.yaml), Secret "alertmanager-aws-credentials" im
# Namespace monitoring. Wie bei den Backup-Konsumenten entsteht der Access Key
# in der Konsole und kommt per kubeseal ins Cluster, es gibt auch hier keine
# aws_iam_access_key-Ressource.
resource "aws_iam_user" "alertmanager" {
  name = "homelab-alertmanager"

  tags = {
    Name      = "alertmanager-sns-publisher"
    ManagedBy = "terraform"
  }
}

# Nur sns:Publish auf genau dieses Topic. Der Alertmanager abonniert nichts und
# liest nichts zurueck.
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
