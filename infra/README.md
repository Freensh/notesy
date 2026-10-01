# Scrib infrastructure (Terraform)

This folder stands in for "the company's AWS infrastructure already exists".
It provisions the whole stack Scrib runs on, including the network, load
balancer, CDN, ECS service, database, image registry and IAM. It does **not**
deploy Scrib itself.

## Placeholder container

The ECS task definition matches the real app's contract: container port 8000,
health check on `/healthz/`, and every environment variable and secret Scrib
reads. Its image, though, is a small placeholder
(`mendhak/http-https-echo`). The placeholder answers `200` on every path, so
right after `terraform apply` you can open `app_url` and see that the whole
chain works: CloudFront → ALB → target group health check → ECS task. You get
back an echo of your request, not Scrib.

The real Scrib app appears only after a CI/CD pipeline builds the image,
pushes it to ECR and registers a new task definition revision in which **only
`image` changes**. Nothing else in the task definition needs to change. The
ECS service ignores `task_definition` drift, so a later `terraform apply` will
not roll the service back to the placeholder.

## Architecture

```
Viewer ──HTTPS──▶ CloudFront ──HTTP──▶ ALB (public subnets) ──▶ ECS Fargate task (private subnets) ──▶ RDS PostgreSQL (private)
                  (TLS ends here)       HTTP :80 only            :8000, /healthz/                       :5432
```

| Component | Details |
|---|---|
| VPC | Two AZs, each with one public and one private subnet. A single NAT gateway serves both. |
| Security groups | `alb-sg` allows 80/443 from anywhere. `ecs-sg` allows `container_port` from `alb-sg` only. `rds-sg` allows 5432 from `ecs-sg` only. |
| ALB | Internet-facing with a single HTTP listener. There is no certificate on the ALB, because TLS terminates at CloudFront. |
| CloudFront | Uses the `CachingDisabled` and `AllViewer` managed policies, so the viewer's `Host` header reaches Django. Serves the default `*.cloudfront.net` domain, or `<subdomain>.<domain_name>`. |
| ECS | Fargate cluster with Container Insights enabled. One task. Logs go to `/ecs/<project>-<environment>`. |
| RDS | PostgreSQL 16. RDS generates the master password and stores it in Secrets Manager (`manage_master_user_password`). |
| Secrets | The RDS-managed secret supplies `POSTGRES_USER` and `POSTGRES_PASSWORD`. A separate secret holds `DJANGO_SECRET_KEY`. |
| ECR | `scrib` repository with scan on push. Untagged images expire after 14 days. |
| GitHub OIDC | Creates the OIDC provider (optional) and one deploy role, `scrib-github-deploy`, with two inline policies: `ecr-push` and `ecs-deploy`. |

JFrog Artifactory needs no AWS IAM. It authenticates with its own access
token, stored as a GitHub secret outside Terraform.

### Container contract

| Variable | Source |
|---|---|
| `POSTGRES_HOST` | RDS endpoint address |
| `POSTGRES_DB` | `var.db_name` |
| `POSTGRES_PORT` | RDS port (5432) |
| `POSTGRES_USER` | RDS-managed secret, `:username::` |
| `POSTGRES_PASSWORD` | RDS-managed secret, `:password::` |
| `DJANGO_SECRET_KEY` | Separate Secrets Manager secret (random, 50 chars) |
| `DJANGO_DEBUG` | `False` |
| `DJANGO_ALLOWED_HOSTS` | `var.django_allowed_hosts` (default `*`, see below) |
| `RUN_MIGRATIONS` | `True` |
| `HTTP_PORT` | Read only by the placeholder image. Scrib ignores it. |

**Migrations.** `desired_count` is deliberately `1`. The service deploys with
`minimum_healthy_percent = 0` and `maximum_percent = 100`, so an old task and a
new one never run at the same time. That makes it safe to run migrations when
the container starts, without a separate one-off migration task. If you scale
beyond one replica, move migrations into a separate `aws ecs run-task` step
first.

**`DJANGO_ALLOWED_HOSTS`.** The default is `*`. The ALB health check sends the
task's private IP as the `Host` header. If Django allowed only the public
hostname, it would answer `/healthz/` with `400` and the target would never
become healthy. The container health check has the same problem with
`localhost`. To use a strict list, first change the app so that it also allows
the task's own IP (for example, read it from the ECS task metadata endpoint in
`settings.py`).

## Usage

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

The first apply takes about 15–20 minutes, mostly for RDS and CloudFront.
Remote state is commented out in `backend.tf`.

### Custom domain (`domain_name`)

- **Empty (default).** No domain is needed. The app is served at the
  CloudFront default domain (`https://dxxxx.cloudfront.net`).
- **Set (e.g. `example.com`).** Terraform looks up the existing public Route53
  zone for `example.com`. It also looks up an existing **ISSUED** ACM
  certificate for `*.example.com` in **us-east-1**. It then creates one new
  alias A record, `scrib.example.com` → CloudFront. It does **not** request
  or validate a certificate. The wildcard SAN already covers the one-label
  subdomain. If no such certificate exists, `plan` fails on the lookup.

## Variables

| Name | Default | Description |
|---|---|---|
| `project_name` | `scrib` | Prefix for resource names |
| `environment` | `prod` | Environment name |
| `aws_region` | `us-east-1` | Region for all regional resources |
| `tags` | `{}` | Extra tags merged into the default tags |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR |
| `public_subnet_cidrs` | `["10.0.1.0/24","10.0.2.0/24"]` | Public subnets, one per AZ |
| `private_subnet_cidrs` | `["10.0.11.0/24","10.0.12.0/24"]` | Private subnets, one per AZ |
| `ecr_repository_name` | `scrib` | ECR repository name |
| `placeholder_image` | `mendhak/http-https-echo:42` | Image used until the pipeline deploys a real build |
| `container_port` | `8000` | Container port (Dockerfile `EXPOSE 8000`) |
| `health_check_path` | `/healthz/` | ALB and container health check path |
| `task_cpu` / `task_memory` | `256` / `512` | Fargate size |
| `desired_count` | `1` | Task count. Keep at 1 (see Migrations above) |
| `log_retention_days` | `14` | CloudWatch log retention |
| `django_allowed_hosts` | `*` | `DJANGO_ALLOWED_HOSTS` value |
| `db_name` | `scrib` | `POSTGRES_DB` |
| `db_username` | `scrib` | RDS master username |
| `db_engine_version` | `16` | PostgreSQL version |
| `db_instance_class` | `db.t4g.micro` | RDS instance class |
| `db_allocated_storage` | `20` | GiB |
| `db_multi_az` | `false` | Multi-AZ RDS |
| `db_skip_final_snapshot` | `true` | Skip the final snapshot on destroy |
| `domain_name` | `""` | Existing Route53 zone. Empty means CloudFront domain only |
| `subdomain` | `scrib` | App subdomain when `domain_name` is set |
| `cloudfront_price_class` | `PriceClass_100` | CloudFront price class |
| `create_github_oidc_provider` | `true` | Create the GitHub OIDC provider. `false` looks up an existing one |
| `github_org` | `""` | GitHub org or user. Empty skips the deploy role |
| `github_repo` | `notesy-app` | Repository name |
| `github_oidc_subjects` | `[]` | Allowed `sub` claims. Empty means `repo:<org>/<repo>:*` |

## Outputs → GitHub secrets

| Output | GitHub secret | Notes |
|---|---|---|
| `ecr_repository_name` | `ECR_REPOSITORY` | |
| `aws_region` | `AWS_REGION` | |
| `ecs_cluster_name` | `ECS_CLUSTER` | |
| `ecs_service_name` | `ECS_SERVICE` | |
| `deploy_role_arn` | `AWS_DEPLOY_ROLE_ARN` | Assumed via OIDC (`aws-actions/configure-aws-credentials`) |
| `ecr_repository_url` | none | Full registry/repo path for `docker tag` |
| `ecs_task_definition_family` | none | Use `aws ecs describe-task-definition` on it, then swap the image |
| `ecs_container_name` | none | Container to put the new image in (`scrib`) |
| `app_url` | none | Where to check the deployment |
| `rds_secret_arn`, `django_secret_key_secret_arn` | none | Already wired into the task definition |
