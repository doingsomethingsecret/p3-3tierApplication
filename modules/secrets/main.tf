# RDS rejects these characters: / @ " and space
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+"
}

# Secret container
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/db-credentials"
  description = "RDS PostgreSQL credentials"

  # 0 = delete immediately on destroy. Otherwise it stays in "scheduled deletion"
  # for 7-30 days and recreating the same name fails.
  recovery_window_in_days = 0
}

# Secret value (JSON)
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
  })
}
