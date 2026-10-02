output "ecr_repository_urls" {
  description = "ECR repository URLs for frontend and backend"
  value       = module.ecr.repository_urls
}

output "rds_address" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.address
}

output "db_secret_arn" {
  description = "ARN of the secret holding the DB credentials"
  value       = module.secrets.db_secret_arn
}

output "app_url" {
  description = "Open this URL in a browser"
  value       = "http://${module.alb.alb_dns_name}"
}

output "cloudmap_namespace" {
  description = "Service Connect private DNS namespace"
  value       = module.cloudmap.namespace_name
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "backend_service" {
  description = "Name of the backend ECS service"
  value       = module.backend.service_name
}

output "frontend_service" {
  description = "Name of the frontend ECS service"
  value       = module.frontend.service_name
}

output "alerts_topic_arn" {
  description = "SNS topic for CloudWatch alarms"
  value       = module.alarms.sns_topic_arn
}
