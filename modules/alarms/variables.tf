variable "name" { type = string }

variable "alert_email" {
  description = "Empty = create alarms only, no email notifications"
  type        = string
  default     = ""
}

variable "cluster_name" { type = string }

variable "ecs_services" {
  description = "label => service name (e.g. frontend => threetier-dev-frontend)"
  type        = map(string)
}

variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
variable "rds_identifier" { type = string }