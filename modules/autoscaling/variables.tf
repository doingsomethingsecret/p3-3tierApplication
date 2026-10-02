variable "name" { type = string }
variable "cluster_name" { type = string }
variable "service_name" { type = string }

variable "min_capacity" {
  type    = number
  default = 2
}
variable "max_capacity" {
  type    = number
  default = 4
}

variable "cpu_target" {
  type    = number
  default = 60
}
variable "memory_target" {
  type    = number
  default = 70
}

variable "scale_out_cooldown" {
  type    = number
  default = 60
}
variable "scale_in_cooldown" {
  type    = number
  default = 300
}




variable "enable_alb_request_scaling" {
  type    = bool
  default = false
}
variable "alb_resource_label" {
  type    = string
  default = ""
}
variable "alb_requests_target" {
  type    = number
  default = 100
}