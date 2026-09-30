output "private_zone_id" {
  value       = try(aws_route53_zone.private[0].zone_id, null)
  description = "ID of the private zone attached to the VPC, null without domain_name"
}
