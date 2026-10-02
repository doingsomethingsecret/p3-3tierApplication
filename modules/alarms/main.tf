# SNS TOPIC + EMAIL SUBSCRIPTION
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ALB ALARMS
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.name}-alb-unhealthy-hosts"
  alarm_description   = "Unhealthy tasks in the frontend target group"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  for_each = toset(["HTTPCode_ELB_5XX_Count", "HTTPCode_Target_5XX_Count"])

  alarm_name          = "${var.name}-alb-${lower(each.key)}"
  alarm_description   = "5xx errors on the ALB: ${each.key}"
  namespace           = "AWS/ApplicationELB"
  metric_name         = each.key
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ECS CPU HIGH (per service)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = var.ecs_services

  alarm_name          = "${var.name}-${each.key}-cpu-high"
  alarm_description   = "${each.key} service CPU above 85%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# RDS ALARMS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  alarm_description   = "RDS CPU above 80%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-storage-low"
  alarm_description   = "RDS free disk below 2 GB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
