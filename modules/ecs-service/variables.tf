variable "name" { type = string }
variable "cluster_arn" { type = string }

variable "launch_type" {
  description = "FARGATE or EC2 (task definition compatibility)"
  type        = string
}

variable "capacity_provider_strategy" {
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
}

# CONTAINER
variable "container_name" { type = string }
variable "image" { type = string }
variable "container_port" { type = number }
variable "port_name" { type = string }
variable "health_path" {
  type    = string
  default = "/health"
}
variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}
variable "environment" {
  type    = map(string)
  default = {}
}
variable "secrets" {
  description = "ENV_NAME => Secrets Manager valueFrom"
  type        = map(string)
  default     = {}
}

# IAM + NETWORK
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }

variable "desired_count" {
  type    = number
  default = 2
}

# DISCOVERY / LB
variable "service_connect_namespace" { type = string }

variable "service_connect_service" {
  description = "null = client only. Object = this service is also published via Service Connect"
  type = object({
    discovery_name = string
    dns_name       = string
    port           = number
  })
  default = null
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "registry_arn" {
  description = "Classic Cloud Map service ARN (optional)"
  type        = string
  default     = null
}

variable "log_retention_days" {
  type    = number
  default = 7
}
variable "attach_to_alb" {
  type    = bool
  default = false
}
variable "register_classic_dns" {
  type    = bool
  default = false
}