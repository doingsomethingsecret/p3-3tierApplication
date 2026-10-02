# LOAD BALANCER (in public subnets)
resource "aws_lb" "this" {
  name                       = "alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  idle_timeout               = 60
  enable_deletion_protection = false # true in production

  tags = { Name = "alb" }
}

# TARGET GROUP (frontend tasks)
resource "aws_lb_target_group" "frontend" {
  name                 = "frontend-tg"
  port                 = var.target_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip" # required for awsvpc/Fargate
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "frontend-tg" }
}

# LISTENER (port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
