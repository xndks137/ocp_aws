resource "aws_route53_record" "all_apps_record" {
  zone_id = var.zone_id
  name    = "*.apps.${var.cluster_name}.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.lb_public_ip]
}
