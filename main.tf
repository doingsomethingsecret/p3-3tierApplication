data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source               = "./modules/vpc"
  name                 = "threetier-dev"
  vpc_cidr             = var.vpc_cidr
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  db_subnet_cidrs      = ["10.0.21.0/24", "10.0.22.0/24"]
}

module "security" {
  source        = "./modules/security"
  name          = "threetier-dev"
  vpc_id        = module.vpc.vpc_id
  frontend_port = 80
  backend_port  = 3000
  db_port       = 5432
}

module "ecr" {
  source = "./modules/ecr"
  name   = "threetier-dev"
}

module "secrets" {
  source = "./modules/secrets"
  name   = "threetier-dev"
}

module "iam" {
  source = "./modules/iam"
  name   = "threetier-dev"
}

module "rds" {
  source        = "./modules/rds"
  name          = "threetier-dev"
  db_subnet_ids = module.vpc.db_subnet_ids
  rds_sg_id     = module.security.rds_sg_id
  username      = module.secrets.db_username
  password      = module.secrets.db_password
}

module "ecs_cluster" {
  source                = "./modules/ecs-cluster"
  name                  = "threetier-dev"
  private_subnet_ids    = module.vpc.private_subnet_ids
  instance_sg_id        = module.security.ecs_instance_sg_id
  instance_profile_name = module.iam.ecs_instance_profile_name
}

module "alb" {
  source            = "./modules/alb"
  name              = "threetier-dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  target_port       = 80
}

module "cloudmap" {
  source = "./modules/cloudmap"
  name   = "threetier-dev"
  vpc_id = module.vpc.vpc_id
}

# BACKEND (EC2 capacity provider)
module "backend" {
  source = "./modules/ecs-service"

  name                 = "threetier-dev-backend"
  cluster_arn          = module.ecs_cluster.cluster_arn
  register_classic_dns = true
  launch_type          = "EC2"

  capacity_provider_strategy = [{
    capacity_provider = module.ecs_cluster.ec2_capacity_provider_name
    weight            = 1
    base              = 0
  }]

  container_name = "backend"
  image          = "${module.ecr.repository_urls["backend"]}:${var.image_tag}"
  container_port = 3000
  port_name      = "backend-port"
  health_path    = "/health"
  cpu            = 256
  memory         = 512
  desired_count  = 2

  environment = {
    PORT    = "3000"
    DB_HOST = module.rds.address
    DB_PORT = "5432"
    DB_NAME = module.rds.db_name
  }

  secrets = {
    DB_USER     = "${module.secrets.db_secret_arn}:username::"
    DB_PASSWORD = "${module.secrets.db_secret_arn}:password::"
  }

  execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn      = module.iam.task_role_arns["backend"]
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.backend_sg_id]

  service_connect_namespace = module.cloudmap.namespace_arn
  service_connect_service = {
    discovery_name = "backend-sc"
    dns_name       = "backend"
    port           = 3000
  }

  registry_arn = module.cloudmap.backend_registry_arn
}

# FRONTEND (Fargate)
module "frontend" {
  source = "./modules/ecs-service"

  name          = "threetier-dev-frontend"
  cluster_arn   = module.ecs_cluster.cluster_arn
  attach_to_alb = true
  launch_type   = "FARGATE"

  capacity_provider_strategy = [{
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }]

  container_name = "frontend"
  image          = "${module.ecr.repository_urls["frontend"]}:${var.image_tag}"
  container_port = 80
  port_name      = "frontend-port"
  health_path    = "/health"
  cpu            = 256
  memory         = 512
  desired_count  = 2

  environment = {
    BACKEND_HOST = "backend" # Service Connect DNS name, not an IP
    BACKEND_PORT = "3000"
  }

  execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn      = module.iam.task_role_arns["frontend"]
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.frontend_sg_id]

  service_connect_namespace = module.cloudmap.namespace_arn

  target_group_arn = module.alb.frontend_target_group_arn

  depends_on = [module.alb, module.backend]
}

# AUTOSCALING
module "autoscaling_frontend" {
  source       = "./modules/autoscaling"
  name         = "threetier-dev-frontend"
  cluster_name = module.ecs_cluster.cluster_name
  service_name = module.frontend.service_name

  min_capacity = 2
  max_capacity = 4

  enable_alb_request_scaling = true
  alb_resource_label         = "${module.alb.alb_arn_suffix}/${module.alb.frontend_target_group_arn_suffix}"
  alb_requests_target        = 100
}

module "autoscaling_backend" {
  source       = "./modules/autoscaling"
  name         = "threetier-dev-backend"
  cluster_name = module.ecs_cluster.cluster_name
  service_name = module.backend.service_name

  min_capacity = 2
  max_capacity = 4
}

# ALARMS
module "alarms" {
  source       = "./modules/alarms"
  name         = "threetier-dev"
  alert_email  = var.alert_email
  cluster_name = module.ecs_cluster.cluster_name

  ecs_services = {
    frontend = module.frontend.service_name
    backend  = module.backend.service_name
  }

  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.frontend_target_group_arn_suffix
  rds_identifier          = module.rds.identifier
}
