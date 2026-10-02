variable "name" { type = string }

variable "repositories" {
  type    = list(string)
  default = ["frontend", "backend"]
}

variable "keep_last_images" {
  type    = number
  default = 10
}
