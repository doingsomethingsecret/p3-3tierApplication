# PRIVATE DNS NAMESPACE
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "local"
  description = "Private DNS namespace for ECS services"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "backend" {
  name = "backend-cloudmap"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl  = 10
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
