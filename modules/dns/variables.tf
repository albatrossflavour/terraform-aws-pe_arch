variable "id" {
  description = "Randomly generated value used to produce unique names for everything"
  type        = string
}
variable "vpc_id" {
  description = "VPC the private zone is attached to"
  type        = string
}
variable "domain_name" {
  description = "Domain the nodes are named under. Nothing is created when null"
  type        = string
  default     = null
}
variable "public_zone_id" {
  description = "Existing public Route 53 zone for domain_name, for publishing public addresses"
  type        = string
  default     = null
}
variable "hosts" {
  description = "Private and public addresses keyed by role name, from the instances module"
  type        = map(object({ private_ip = string, public_ip = string }))
}
variable "has_lb" {
  description = "Whether a compiler load balancer exists. Known at plan time, unlike its DNS name"
  type        = bool
}
variable "lb_dns_name" {
  description = "DNS name of the compiler load balancer, null when there isn't one"
  type        = string
  default     = null
}
variable "lb_zone_id" {
  description = "Route 53 zone ID of the compiler load balancer, for the alias record"
  type        = string
  default     = null
}
