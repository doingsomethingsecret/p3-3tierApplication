output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}