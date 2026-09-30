# Output data used by Bolt to do further work, doing this allows for a clean and
# abstracted interface between cloud provider implementations
output "console" {
  value       = var.domain_name == null ? module.instances.console : "primary-1.${var.domain_name}"
  description = "Address of the Puppet Enterprise console: the primary's name when domain_name is set, otherwise its IP"
}
output "pool" {
  value       = var.domain_name == null ? module.loadbalancer.lb_dns_name : "puppet.${var.domain_name}"
  description = "Name agents use for the compiler pool: puppet.<domain_name> when set, otherwise the load balancer's or primary's AWS DNS name"
}

# For layers built beside the deployment, such as a fleet of test agents
output "vpc_id" {
  value       = module.networking.vpc_id
  description = "VPC the deployment runs in"
}
output "subnet_ids" {
  value       = module.networking.subnet_ids
  description = "Subnets the deployment's instances are spread across"
}
output "security_group_id" {
  value       = module.networking.security_group_ids[0]
  description = "Security group shared by every node"
}
output "private_zone_id" {
  value       = module.dns.private_zone_id
  description = "Private Route 53 zone for domain_name, null without one"
}
output "public_zone_id" {
  value       = var.public_zone_id
  description = "Public Route 53 zone for domain_name, as passed in"
}
output "domain_name" {
  value       = var.domain_name
  description = "Domain the nodes are named under, null without one"
}
output "deployment_id" {
  value       = random_id.deployment.hex
  description = "Random ID of this deployment, which changes on every rebuild"
}
output "key_name" {
  value       = module.instances.key_name
  description = "EC2 key pair holding the operator's SSH public key"
}
