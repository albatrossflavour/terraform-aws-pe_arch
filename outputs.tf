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
