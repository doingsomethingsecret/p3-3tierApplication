output "alb_sg_id" { value = aws_security_group.alb.id }
output "frontend_sg_id" { value = aws_security_group.frontend.id }
output "backend_sg_id" { value = aws_security_group.backend.id }
output "rds_sg_id" { value = aws_security_group.rds.id }
output "ecs_instance_sg_id" { value = aws_security_group.ecs_instance.id }