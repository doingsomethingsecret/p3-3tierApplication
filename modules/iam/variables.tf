variable "name" { type = string }

variable "task_role_names" {
  type    = list(string)
  default = ["frontend", "backend"]
}