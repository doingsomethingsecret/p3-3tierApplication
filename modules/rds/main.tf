resource "aws_db_subnet_group" "this" {
  name       = "db-subnets"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "db-subnets" }
}

resource "aws_db_instance" "this" {
  identifier = "postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  # Dev settings (set all three to true in production)
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = { Name = "postgres" }
}
