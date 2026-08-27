# A cost signal on the account. Until now unwanted growth would have shown up
# on the invoice and nowhere else: the freshness probe watches whether backups
# arrive, not what they cost, and nothing else looks at spend at all.
#
# The concrete case this covers is the paperless bucket. Its objects carry an
# Object Lock retention of ten years, so anything written stays written, and
# whoever reaches paperless can push new documents through the export into S3.
# The 10 Gi export volume caps a single run, but not the sum over months.
#
# Budgets is a global service. The resource has no region, the budget ARN
# carries none either (arn:aws:budgets::<account>:budget/<name>).
resource "aws_budgets_budget" "account" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Both notifications go to the SNS topic rather than to an email address of
  # their own. The subscription on that topic is confirmed, while a fresh
  # SUBSCRIBER of type EMAIL would start out unconfirmed and stay silent until
  # someone clicks the link, without anything failing anywhere.
  #
  # Budgets may only publish there because of the "BudgetsPublish" statement in
  # sns-alerts.tf. Without it the budget is created and its notifications
  # silently never arrive.

  # ACTUAL: spend that has already happened. Fires once, at 80 percent.
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = var.budget_actual_threshold_percent
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  # FORECASTED: where the month is heading at the current rate. This is the
  # half that catches a slow leak early, because the projection crosses the
  # limit long before the actual spend does.
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = var.budget_forecast_threshold_percent
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }
}
