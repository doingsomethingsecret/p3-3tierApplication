output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_arn" { value = aws_lb.this.arn }
output "frontend_target_group_arn" { value = aws_lb_target_group.frontend.arn }
output "listener_arn" { value = aws_lb_listener.http.arn }

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "frontend_target_group_arn_suffix" {
  value = aws_lb_target_group.frontend.arn_suffix
}