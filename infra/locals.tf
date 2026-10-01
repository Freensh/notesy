locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  # Custom domain is opt-in: empty domain_name = CloudFront default domain only.
  use_custom_domain = var.domain_name != ""
  fqdn              = local.use_custom_domain ? "${var.subdomain}.${var.domain_name}" : null

  # Hostname viewers use; CloudFront forwards it to the ALB as the Host header.
  app_host = local.use_custom_domain ? local.fqdn : aws_cloudfront_distribution.main.domain_name

  container_name = var.project_name

  create_github_deploy_role = var.github_org != ""
  github_oidc_subjects = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : [
    "repo:${var.github_org}/${var.github_repo}:*",
  ]
}
