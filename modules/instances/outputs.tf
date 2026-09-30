# Output data that will be used by other submodules to build other parts of the
# stack to support defined architecture
output "console" {
  value       = coalesce(aws_instance.server[0].public_ip, aws_instance.server[0].private_ip)
  description = "This will be the external IP address assigned to the Puppet Enterprise console"
}
output "compilers" {
  value       = var.compiler_count == 0 ? aws_instance.server[*] : aws_instance.compiler[*]
  description = "Depending on architecture, either the primary master or the group of compilers created by the module for use by other modules"
}
output "hosts" {
  value = var.domain_name == null ? {} : {
    for idx, i in local.instances : local.role_names[idx] => {
      private_ip = i.private_ip
      public_ip  = i.public_ip
    }
  }
  description = "Private and public addresses by role name, empty unless domain_name is set"
}
output "key_name" {
  value       = aws_key_pair.pe_adm.key_name
  description = "EC2 key pair holding the operator's SSH public key"
}
