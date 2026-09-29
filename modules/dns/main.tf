# Split-horizon DNS for the deployment. A private zone attached to the VPC
# answers for every node with its private address, so certnames resolve between
# nodes. When a public zone is given, the same names are published there with
# public addresses, for the operator's own access to the console and SSH.
#
# `puppet` is the name agents use. It follows the compiler pool, so it only goes
# in the private zone: the load balancer is internal, and agents sit inside the
# VPC.

locals {
  create_private = var.domain_name != null
  create_public  = local.create_private && var.public_zone_id != null
  public_hosts   = local.create_public ? var.hosts : {}
}

resource "aws_route53_zone" "private" {
  count         = local.create_private ? 1 : 0
  name          = var.domain_name
  comment       = "pecdm ${var.id}: private addresses for ${var.domain_name}"
  force_destroy = true

  vpc {
    vpc_id = var.vpc_id
  }

  tags = { Name = "pe-${var.id}" }
}

resource "aws_route53_record" "private" {
  for_each = local.create_private ? var.hosts : {}
  zone_id  = aws_route53_zone.private[0].zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = 60
  records  = [each.value.private_ip]
}

# The compiler pool: an alias to the load balancer when there is one, otherwise
# the primary itself
resource "aws_route53_record" "pool_lb" {
  count   = local.create_private && var.has_lb ? 1 : 0
  zone_id = aws_route53_zone.private[0].zone_id
  name    = "puppet.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.lb_dns_name
    zone_id                = var.lb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "pool_primary" {
  count   = local.create_private && !var.has_lb ? 1 : 0
  zone_id = aws_route53_zone.private[0].zone_id
  name    = "puppet.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [var.hosts["primary-1"].private_ip]
}

resource "aws_route53_record" "public" {
  for_each = local.public_hosts
  zone_id  = var.public_zone_id
  name     = "${each.key}.${var.domain_name}"
  type     = "A"
  ttl      = 60
  records  = [each.value.public_ip]
}
