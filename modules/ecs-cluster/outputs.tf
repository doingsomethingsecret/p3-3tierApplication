output "cluster_name" { value = aws_ecs_cluster.this.name }
output "cluster_arn" { value = aws_ecs_cluster.this.arn }
output "ec2_capacity_provider_name" { value = aws_ecs_capacity_provider.ec2.name }
output "asg_name" { value = aws_autoscaling_group.ecs.name }