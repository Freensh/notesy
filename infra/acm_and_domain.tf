# Custom domain (only when var.domain_name is set). Nothing here requests or
# validates a certificate: it reuses an EXISTING wildcard cert whose
# "*.<domain_name>" SAN already covers <subdomain>.<domain_name>.
data "aws_acm_certificate" "wildcard" {
  count       = local.use_custom_domain ? 1 : 0
  provider    = aws.us_east_1
  domain      = "*.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "main" {
  count        = local.use_custom_domain ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "app" {
  count   = local.use_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
