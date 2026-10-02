variable "name" { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "rds_sg_id" { type = string }

variable "db_name" {
  type    = string
  default = "appdb"
}
variable "username" { type = string }
variable "password" {
  type      = string
  sensitive = true
}

variable "engine_version" {
  type    = string
  default = "16"
}
variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "multi_az" {
  type    = bool
  default = false
}
