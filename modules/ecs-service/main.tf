data "aws_region" "current" {}

# CLOUDWATCH LOG GROUP
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
}

# TASK DEFINITION
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = [var.launch_type]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.image
      essential = true

      portMappings = [{
        name          = var.port_name
        containerPort = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [for k, v in var.environment : { name = k, value = v }]
      secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }

      # Service Connect only routes traffic once this is healthy
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:${var.container_port}${var.health_path} >/dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

# ECS SERVICE
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  enable_execute_command = true # ECS Exec (shell without SSH)

  health_check_grace_period_seconds = var.attach_to_alb ? 60 : null

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Roll back automatically if the new version fails
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.attach_to_alb ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.register_classic_dns ? [1] : []
    content {
      registry_arn = var.registry_arn
    }
  }

  # Service Connect
  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace

    dynamic "service" {
      for_each = var.service_connect_service == null ? [] : [var.service_connect_service]
      content {
        port_name      = var.port_name
        discovery_name = service.value.discovery_name

        client_alias {
          port     = service.value.port
          dns_name = service.value.dns_name
        }
      }
    }
  }

  # Autoscaling controls desired_count
  lifecycle {
    ignore_changes = [desired_count]
  }
}
