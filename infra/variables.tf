###############################################################################
# General
###############################################################################

variable "project_name" {
  description = "Project name, used as a prefix for resource names."
  type        = string
  default     = "scrib"
}

variable "environment" {
  description = "Environment name (e.g. prod, staging)."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for all regional resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Extra tags merged into the default tags on every resource."
  type        = map(string)
  default     = {}
}

###############################################################################
# Network
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets (ALB, NAT gateway), one per AZ."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required (one per AZ)."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the two private subnets (ECS tasks, RDS), one per AZ."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs are required (one per AZ)."
  }
}

###############################################################################
# Container / ECS
###############################################################################

variable "ecr_repository_name" {
  description = "Name of the ECR repository the CI/CD pipeline pushes Scrib images to."
  type        = string
  default     = "scrib"
}

variable "placeholder_image" {
  description = <<-EOT
    Image deployed until the pipeline swaps in a real Scrib build. It must
    listen on var.container_port using only environment variables (no command
    override, so the real image's ENTRYPOINT/CMD are untouched), answer 200 on
    var.health_check_path, and contain /bin/sh + wget for the container health
    check fallback. mendhak/http-https-echo meets all three via HTTP_PORT.
  EOT
  type        = string
  default     = "mendhak/http-https-echo:42"
}

variable "container_port" {
  description = "Port the container listens on. Matches EXPOSE 8000 / gunicorn --bind 0.0.0.0:8000 in the Dockerfile."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Health check path. Matches path(\"healthz/\", ...) in scrib/urls.py."
  type        = string
  default     = "/healthz/"
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running tasks. Deliberately 1: migrations run in the container entrypoint (see ecs.tf)."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the ECS log group."
  type        = number
  default     = 14
}

variable "django_allowed_hosts" {
  description = <<-EOT
    Value for DJANGO_ALLOWED_HOSTS. Defaults to "*" because the ALB health
    check sends the task's private IP as the Host header, which Django would
    reject with 400 if the list only contained the public hostname. Set to an
    explicit list only after the app also allows the task IP (see README).
  EOT
  type        = string
  default     = "*"
}

###############################################################################
# Database
###############################################################################

variable "db_name" {
  description = "Initial database name (POSTGRES_DB)."
  type        = string
  default     = "scrib"
}

variable "db_username" {
  description = "Master username. The password is generated and stored by RDS in Secrets Manager."
  type        = string
  default     = "scrib"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version (matches postgres:16 in docker-compose.yml)."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Whether to run RDS Multi-AZ."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Set false for anything holding real data."
  type        = bool
  default     = true
}

###############################################################################
# Domain / CloudFront
###############################################################################

variable "domain_name" {
  description = <<-EOT
    Existing Route53 public hosted zone (e.g. "example.com"). Leave empty to
    skip the custom domain and use only the CloudFront default domain. When
    set, an EXISTING ISSUED ACM certificate for "*.<domain_name>" in us-east-1
    must already exist; no certificate is requested or validated here.
  EOT
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for the app when domain_name is set (fqdn = <subdomain>.<domain_name>)."
  type        = string
  default     = "scrib"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

###############################################################################
# GitHub OIDC
###############################################################################

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false if the account already has one (it is then looked up)."
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub org/user that owns the repo. Leave empty to skip creating the deploy role."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name (without the org)."
  type        = string
  default     = "notesy-app"
}

variable "github_oidc_subjects" {
  description = "Allowed OIDC 'sub' claims for the deploy role. Empty = repo:<github_org>/<github_repo>:*."
  type        = list(string)
  default     = []
}
