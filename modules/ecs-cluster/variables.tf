variable "name" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "instance_sg_id" { type = string }
variable "instance_profile_name" { type = string }

variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "min_size" {
  type    = number
  default = 1
}
variable "max_size" {
  type    = number
  default = 3
}