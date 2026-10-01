output "ecr_repository_name" {
  description = "ECR repository name. GitHub secret: ECR_REPOSITORY."
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  description = "Full ECR repository URL (<account>.dkr.ecr.<region>.amazonaws.com/<name>) to tag and push images to."
  value       = aws_ecr_repository.app.repository_url
}

output "aws_region" {
  description = "AWS region. GitHub secret: AWS_REGION."
  value       = var.aws_region
}

output "ecs_cluster_name" {
  description = "ECS cluster name. GitHub secret: ECS_CLUSTER."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name. GitHub secret: ECS_SERVICE."
  value       = aws_ecs_service.app.name
}

output "ecs_task_definition_family" {
  description = "Task definition family; fetch the current revision with `aws ecs describe-task-definition --task-definition <family>` and swap only the image."
  value       = aws_ecs_task_definition.app.family
}

output "ecs_container_name" {
  description = "Container name inside the task definition (needed when rendering a new image into it)."
  value       = local.container_name
}

output "app_url" {
  description = "Public URL of the app (CloudFront default domain, or https://<subdomain>.<domain_name>)."
  value       = "https://${local.app_host}"
}

output "deploy_role_arn" {
  description = "IAM role GitHub Actions assumes via OIDC (null if github_org is empty). GitHub secret: AWS_DEPLOY_ROLE_ARN."
  value       = local.create_github_deploy_role ? aws_iam_role.github_deploy[0].arn : null
}

output "rds_secret_arn" {
  description = "RDS-managed Secrets Manager secret holding the DB username/password (already wired into the task definition)."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "django_secret_key_secret_arn" {
  description = "Secrets Manager secret holding DJANGO_SECRET_KEY (already wired into the task definition)."
  value       = aws_secretsmanager_secret.django_secret_key.arn
}
