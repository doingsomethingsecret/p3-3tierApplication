# 3-Tier Application on AWS ECS

A production-oriented three-tier application (nginx frontend → Express backend → PostgreSQL) deployed on a single ECS cluster that runs **both Fargate and managed EC2 capacity providers**, with **Service Connect + AWS Cloud Map** for service discovery.

---

## Architecture

```
                        ┌──────────────────────┐
                 ┌──────│   Internet           │
                 │      └──────────┬───────────┘
            ┌────▼────┐            │
            │  ALB    │  :80       │  Public subnets
            │  alb    │            │  10.0.1.0/24, 10.0.2.0/24
            └────┬────┘            │
                 │                 │  ┌─────────┐
                 │                 └──│   NAT   │ (single, in public-1)
        ┌────────▼─────────┐        │  └─────────┘
        │  frontend        │        │  Private subnets
        │  Fargate × 2     │        │  10.0.11.0/24, 10.0.12.0/24
        │  nginx :80       │        │
        └────────┬─────────┘        │  ┌──────────────┐
                 │ Service Connect  │  │ ASG ecs-asg  │
                 │ DNS: "backend"   │  │ t3.small 1–3 │
                 │ :3000            │  │ ECS-optimized│
                 │                  │  │ AL2023       │
        ┌────────▼─────────┐        │  └──────┬───────┘
        │  backend         │◀───────┘         │
        │  EC2 × 2         │  capacity provider
        │  express :3000   │  "ec2-cp"
        └────────┬─────────┘
                 │ :5432          │  DB subnets (isolated)
        ┌────────▼─────────┐      │  10.0.21.0/24, 10.0.22.0/24
        │  RDS PostgreSQL  │◀─────┘
        │  db.t4g.micro    │
        │  gp3 · encrypted │      ┌──────────────────────────┐
        └──────────────────┘      │ Secrets Manager          │
                                  │ threetier-dev/db-        │
                                  │   credentials            │
                                  └──────────────────────────┘
```

**Traffic flow:** `Internet → ALB → frontend:80 → backend:3000 → RDS:5432`. Every hop is restricted by a security group; the DB has no egress route at all.

---

## Service Discovery

Both AWS-native mechanisms are implemented, so no IP addresses are ever hardcoded:

| Mechanism | Resource | Purpose |
|---|---|---|
| **Service Connect** | namespace `local`, endpoint `backend-sc` | Managed proxy sidecar. Frontend resolves `backend` (client alias) inside the namespace; ECS handles load balancing, outlier detection and retries. |
| **Cloud Map (classic)** | namespace `local`, service `backend-cloudmap` | Classic A-record registration (`backend-cloudmap.local`) via `service_registries`, for non-ECS consumers in the VPC. |

The two names are deliberately distinct — AWS requires unique names per namespace, otherwise `backend.local` collides.

Frontend config uses the discovery name, not an IP:

```hcl
environment = {
  BACKEND_HOST = "backend"  # Service Connect DNS name, not an IP
  BACKEND_PORT = "3000"
}
```

---

## Capacity Providers

One cluster (`ecs-cluster`), three providers, two in use:

| Service | Provider | Launch type | Reason |
|---|---|---|---|
| `threetier-dev-frontend` | `FARGATE` | Fargate | Stateless HTTP, scales from zero |
| `threetier-dev-backend` | `ec2-cp` | EC2 | Long-lived connections, predictable CPU |

The EC2 side uses an Auto Scaling Group (`ecs-asg`, 1–3 × `t3.small`) tagged `AmazonECSManaged`, wired to the cluster through `aws_ecs_capacity_provider` with managed scaling at 100% target utilisation and managed termination protection. Terraform releases control of `desired_capacity` to the provider via `ignore_changes`.

---

## Project Structure

```
.
├── main.tf              # Module wiring + service definitions
├── variables.tf         # Region, VPC CIDR, alert email, image tag
├── outputs.tf           # App URL, service names, secret ARN
├── versions.tf          # AWS ~> 5.0, random ~> 3.6
├── app/
│   ├── backend/         # Express + pg (Node 20, alpine)
│   └── frontend/        # nginx 1.27 + static UI
└── modules/             # 12 self-contained modules
    ├── vpc/             # Public/private/db subnets, NAT, route tables
    ├── security/        # 5 SGs + granular ingress/egress rules
    ├── ecr/             # frontend + backend repos, scan-on-push, lifecycle
    ├── secrets/         # DB credentials in Secrets Manager
    ├── iam/             # Task, task execution, EC2 instance roles
    ├── rds/             # PostgreSQL in isolated subnets
    ├── ecs-cluster/     # Cluster, launch template, ASG, capacity providers
    ├── ecs-service/     # Task definition + service (reusable)
    ├── alb/             # ALB, target group, listener
    ├── cloudmap/        # Private DNS namespace + classic service
    ├── autoscaling/     # CPU / memory / ALB-request target tracking
    └── alarms/          # SNS topic + CloudWatch alarms
```

Every module is independently reusable: `ecs-service` takes a capacity provider strategy, launch type, and optional ALB / Service Connect / Cloud Map attachments as flags, so both services share one implementation.

---

## Prerequisites

- Terraform >= 1.6
- AWS CLI v2 with valid credentials (`aws sts get-caller-identity`)
- Docker
- Region configured in `terraform.tfvars` (default `us-east-1`)

---

## Deploy

### 1. Initialize

```bash
terraform init
```

### 2. Create ECR repositories first

`aws_ecs_service` waits for steady state. Without images in ECR the tasks never start and `apply` times out — so create the repositories up front:

```bash
terraform apply -target=module.ecr
```

### 3. Build and push images

```bash
REG=<account-id>.dkr.ecr.us-east-1.amazonaws.com

aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $REG

docker build -t $REG/backend:latest  app/backend/  && docker push $REG/backend:latest
docker build -t $REG/frontend:latest app/frontend/ && docker push $REG/frontend:latest
```

### 4. Deploy everything

```bash
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Takes roughly 15–20 minutes (NAT gateway and RDS are the slow resources).

---

## Verify

```bash
terraform output app_url          # open this in a browser

aws ecs describe-services --cluster ecs-cluster \
  --services threetier-dev-frontend threetier-dev-backend \
  --query 'services[].{name:serviceName,running:runningCount,type:launchType}'

aws logs tail /ecs/threetier-dev-backend --follow
```

The UI should report a backend hostname and `Database: connected`. Confirm discovery works by resolving the backend from inside a frontend task:

```bash
FRONTEND_TASK=$(aws ecs list-tasks --cluster ecs-cluster \
  --service-name threetier-dev-frontend --query 'taskArns[0]' --output text)

aws ecs execute-command --cluster ecs-cluster --task $FRONTEND_TASK \
  --container frontend --interactive --command "nslookup backend.local"
```

### Key resources

| Resource | Name |
|---|---|
| ECS cluster | `ecs-cluster` |
| Frontend service | `threetier-dev-frontend` |
| Backend service | `threetier-dev-backend` |
| Log groups | `/ecs/threetier-dev-frontend`, `/ecs/threetier-dev-backend` |
| ALB / target group | `alb` / `frontend-tg` |
| Secret | `threetier-dev/db-credentials` |
| Alarm topic | `threetier-dev-alerts` |

---

## Security Model

| Control | Implementation |
|---|---|
| **Secrets** | DB password generated by `random_password` and stored in Secrets Manager; injected as task secrets, never as plain environment variables |
| **IAM** | Separate task role per service, shared execution role, dedicated EC2 instance role |
| **Least privilege** | Execution role can read only `secret:threetier-dev/*` |
| **Confused deputy** | All ECS task roles assume-role policy pinned to the account via `aws:SourceAccount` |
| **Network** | ALB accepts :80 from the internet only; DB accepts :5432 from the backend SG only and has **no egress rule** |
| **No SSH** | ECS instances have no inbound rules; access is via SSM Session Manager |
| **Encryption** | RDS storage encrypted at rest; ECR AES256; EC2 root volume encrypted |
| **IMDSv2** | Launch template sets `http_tokens = required` |
| **Alarms** | ALB unhealthy hosts, ALB 5xx, per-service CPU, RDS CPU and free storage |

---

## Scaling and Observability

**Task autoscaling** (2–4 tasks per service):

| Signal | Target | Service |
|---|---|---|
| `ECSServiceAverageCPUUtilization` | 60% | both |
| `ECSServiceAverageMemoryUtilization` | 70% | both |
| `ALBRequestCountPerTarget` | 100 req | frontend |

**Deployment safety** — circuit breaker with automatic rollback, 60s ALB health grace period, 30s deregistration delay so in-flight requests drain.

---

## Local Development

No AWS account needed:

```bash
# 1. PostgreSQL
docker run -d --name pg -e POSTGRES_PASSWORD=pass -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=dbadmin -p 5432:5432 postgres:16

# 2. Backend
cd app/backend && npm install
PORT=3000 DB_HOST=localhost DB_PORT=5432 DB_NAME=appdb \
  DB_USER=dbadmin DB_PASSWORD=pass DB_SSL=false node server.js

# 3. Frontend
cd app/frontend && docker build -t fe:latest .
docker run -d --name fe -p 8080:80 \
  -e BACKEND_HOST=host.docker.internal -e BACKEND_PORT=3000 fe:latest
```

Open `http://localhost:8080`. `DB_SSL=false` is required — the backend enables SSL by default for RDS, but a local Postgres container does not use it.

---

## Teardown

```bash
terraform destroy
```

Configured to complete without hanging: ECR repos use `force_delete`, the secret uses `recovery_window_in_days = 0`, and the ASG uses `force_delete` alongside `protect_from_scale_in`. RDS has `skip_final_snapshot = true` — **all database data is deleted**.

---

## Known Limitations

This is a strong dev/staging baseline. Before production:

| Area | Current | Recommended |
|---|---|---|
| **TLS** | ALB listens on HTTP :80 | Add ACM certificate and an HTTPS listener |
| **NAT HA** | Single NAT gateway in `public-1` | One per AZ for cross-AZ failover |
| **RDS durability** | Single-AZ, 1-day backups | `multi_az = true`, 7–14 day retention, final snapshots |
| **Deletion safety** | `deletion_protection = false` | Enable for production databases |
| **State** | Local state file | Configure an S3 backend with locking |
| **Naming** | Most resource names are hardcoded | Wire the `name` variable through for multi-environment use |
| **Access logs** | ECS logs only | Enable ALB access logs |
| **ALB updates** | `apply_immediately = true` | Disable for production RDS |
