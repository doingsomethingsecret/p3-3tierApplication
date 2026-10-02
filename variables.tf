variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "image_tag" {
  type    = string
  default = "latest"
}
