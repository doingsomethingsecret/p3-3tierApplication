variable "name" { type = string }
variable "vpc_id" { type = string }
variable "frontend_port" {
  type    = number
  default = 80
}
variable "backend_port" {
  type    = number
  default = 3000
}
variable "db_port" {
  type    = number
  default = 5432
}
