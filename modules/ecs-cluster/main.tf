# ECS CLUSTER
resource "aws_ecs_cluster" "this" {
  name = "ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Latest ECS-optimized Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# LAUNCH TEMPLATE
resource "aws_launch_template" "ecs" {
  name_prefix   = "ecs-lt-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [var.instance_sg_id]

  # Tell the agent the cluster name at boot
  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
  EOT
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # IMDSv2 only
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "ecs-instance" }
  }
}

# AUTO SCALING GROUP
resource "aws_autoscaling_group" "ecs" {
  name                  = "ecs-asg"
  vpc_zone_identifier   = var.private_subnet_ids
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.min_size
  protect_from_scale_in = true # required for managed termination protection
  force_delete          = true # so destroy does not block on protected instances
  health_check_type     = "EC2"

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  # ECS treats an ASG with this tag as managed
  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  # The capacity provider controls desired_capacity now
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# CAPACITY PROVIDER (EC2)
resource "aws_ecs_capacity_provider" "ec2" {
  name = "ec2-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}

# ATTACH CAPACITY PROVIDERS TO CLUSTER
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT",
    aws_ecs_capacity_provider.ec2.name,
  ]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
}
