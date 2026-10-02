# SECURITY GROUPS (containers only, rules separate)
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Public ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "alb-sg" }
}

resource "aws_security_group" "frontend" {
  name        = "frontend-sg"
  description = "Frontend ECS tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "frontend-sg" }
}

resource "aws_security_group" "backend" {
  name        = "backend-sg"
  description = "Backend ECS tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "backend-sg" }
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "PostgreSQL RDS"
  vpc_id      = var.vpc_id
  tags        = { Name = "rds-sg" }
}

resource "aws_security_group" "ecs_instance" {
  name        = "ecs-instance-sg"
  description = "ECS EC2 container instances (host level)"
  vpc_id      = var.vpc_id
  tags        = { Name = "ecs-instance-sg" }
}

# ALB RULES
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to frontend tasks only"
  referenced_security_group_id = aws_security_group.frontend.id
  from_port                    = var.frontend_port
  to_port                      = var.frontend_port
  ip_protocol                  = "tcp"
}

# FRONTEND RULES
resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "From ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.frontend_port
  to_port                      = var.frontend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "frontend_all" {
  security_group_id = aws_security_group.frontend.id
  description       = "Outbound (ECR, logs, backend)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# BACKEND RULES
resource "aws_vpc_security_group_ingress_rule" "backend_from_frontend" {
  security_group_id            = aws_security_group.backend.id
  description                  = "From frontend only"
  referenced_security_group_id = aws_security_group.frontend.id
  from_port                    = var.backend_port
  to_port                      = var.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_all" {
  security_group_id = aws_security_group.backend.id
  description       = "Outbound (RDS, Secrets Manager, ECR)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# RDS RULES
# No egress rule: the DB must not make outbound connections
resource "aws_vpc_security_group_ingress_rule" "rds_from_backend" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from backend only"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
}

# ECS EC2 INSTANCE RULES
# No ingress: no SSH, no inbound access
resource "aws_vpc_security_group_egress_rule" "instance_all" {
  security_group_id = aws_security_group.ecs_instance.id
  description       = "Agent needs access to ECS/ECR/CloudWatch"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
