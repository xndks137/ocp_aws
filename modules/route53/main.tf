resource "aws_route53_record" "api_record" {
  zone_id = var.zone_id
  name    = "api.${var.cluster_name}.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = [ var.lb_public_ip ]
}

resource "aws_route53_record" "api-int_record" {
  zone_id = var.zone_id
  name    = "api-int.${var.cluster_name}.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = [ var.lb_public_ip ]
}

resource "aws_route53_record" "apps_record" {
  zone_id = var.zone_id
  name    = "apps.${var.cluster_name}.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = [ var.lb_public_ip ]
}

resource "aws_route53_record" "all_apps_record" {
  zone_id = var.zone_id
  name    = "*.apps.${var.cluster_name}.${var.zone_name}"
  type    = "A"
  ttl     = 300
  records = [ var.lb_public_ip ]
}
