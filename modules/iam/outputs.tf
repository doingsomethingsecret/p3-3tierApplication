output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arns" {
  value = { for k, r in aws_iam_role.task : k => r.arn }
}

output "ecs_instance_profile_name" {
  value = aws_iam_instance_profile.ecs_instance.name
}

output "ecs_instance_profile_arn" {
  value = aws_iam_instance_profile.ecs_instance.arn
}