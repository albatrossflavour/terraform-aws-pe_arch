# To contain each PE deployment, a fresh VPC to deploy into
locals {
  name_tag = {
    Name = "pe-${var.id}"
  }
  network_count = var.to_create ? 1 : 0
  vpc_id        = try(aws_vpc.pe[0].id, data.aws_vpc.existing[0].id)
  subnet_ids    = coalescelist(aws_subnet.pe_subnet[*].id, data.aws_subnet.existing[*].id)
}

data "aws_availability_zones" "available" {}

data "aws_subnet" "existing" {
  count = var.to_create ? 0 : length(toset(var.subnet))
  id    = var.subnet[count.index]
}

data "aws_vpc" "existing" {
  count = var.to_create ? 0 : 1
  id    = try(distinct(data.aws_subnet.existing[*].vpc_id)[0], null)
}

resource "aws_vpc" "pe" {
  count                = local.network_count
  cidr_block           = "10.138.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.name_tag
}

resource "aws_internet_gateway" "pe_gw" {
  count  = local.network_count
  vpc_id = local.vpc_id

  tags = local.name_tag
}

#TODO implement a subnet per availability zone
resource "aws_subnet" "pe_subnet" {
  count             = var.to_create ? length(data.aws_availability_zones.available.names) : local.network_count
  vpc_id            = local.vpc_id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  cidr_block              = "10.138.${1 + count.index}.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "pe-${var.id}-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table" "pe_public" {
  count  = local.network_count
  vpc_id = local.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pe_gw[0].id
  }
  tags = local.name_tag
}

resource "aws_route_table_association" "pe_subnet_public" {
  count          = var.to_create ? length(aws_subnet.pe_subnet) : local.network_count
  subnet_id      = aws_subnet.pe_subnet[count.index].id
  route_table_id = aws_route_table.pe_public[0].id
}

# Instances should not be accessible by the open internet so a fresh VPC should
# be restricted to organization allowed subnets
resource "aws_security_group" "pe_sg" {
  name        = "pe-${var.id}"
  description = "PE nodes: operator ports from allowed ranges, anything within the VPC"
  vpc_id      = local.vpc_id

  # Only the ports an operator needs, and only from the allowed ranges: SSH for
  # Bolt, the console, and the APIs PE's client tools talk to
  dynamic "ingress" {
    for_each = length(var.allow) == 0 ? [] : var.operator_ports
    content {
      description = "Operator access on ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allow
    }
  }

  # Nodes, agents and the load balancer's health checks all come from inside the
  # VPC. The NLB has no security group of its own, so this can't be narrowed to
  # a self-reference
  ingress {
    description = "Anything from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols and ports
    cidr_blocks = tolist([try(aws_vpc.pe[0].cidr_block, data.aws_vpc.existing[0].cidr_block)])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.name_tag
}
