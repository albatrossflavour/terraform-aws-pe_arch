# This data source will produce the most recent AMI with the name pattern as
# provided in var.instance_image and owner as specified.
#
# To use AMIs by this owner, an EULA has to be accepted once using the AWS
# Console.
data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.instance_image]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  dynamic "filter" {
    for_each = var.image_product_code == null ? [] : [1]
    content {
      name   = "product-code"
      values = [var.image_product_code]
    }
  }

  owners = [var.image_owner]
}


# The default tags are needed to prevent Puppet AWS reaper from reaping the instances
locals {
  tags = merge({
    description = "PEADM Deployed Puppet Enterprise"
    project     = var.project
  }, var.tags)

  # Role names used for certnames when a domain is given. They follow the
  # resource order below and are built from the counts, so they are known at
  # plan time. server[0] is the primary and server[1], when present, its replica
  role_names = concat(
    [for i in range(var.server_count) : i == 0 ? "primary-1" : "replica-${i}"],
    [for i in range(var.database_count) : "postgres-${i + 1}"],
    [for i in range(var.compiler_count) : "compiler-${i + 1}"],
    [for i in range(var.node_count) : "agent-${i + 1}"],
  )
  instances = flatten([
    aws_instance.server[*],
    aws_instance.psql[*],
    aws_instance.compiler[*],
    aws_instance.node[*]
  ])
  servers = [for idx, i in local.instances :
    [i.id,
      var.domain_name == null ? i.private_dns :
    "${local.role_names[idx]}.${var.domain_name}"]
  ]
}

resource "aws_key_pair" "pe_adm" {
  key_name   = "pe_adm_${var.id}"
  public_key = file(var.ssh_key)
  tags       = local.tags
}

# Additional internalDNS depends on instances to be deployed to determine the
# value of private_dns, instance resources ignore content of this tag
resource "aws_ec2_tag" "internalDNS" {
  count       = length(local.servers)
  resource_id = local.servers[count.index][0]
  key         = "internalDNS"
  value       = local.servers[count.index][1]
}

# In both large and standard we only require a single Primary but under a
# standard architecture the instance will also serve catalogs as a Compiler in
# addition to hosting all other core services. 
resource "aws_instance" "server" {
  ami                    = data.aws_ami.ami.id
  instance_type          = var.primary_type
  count                  = var.server_count
  key_name               = aws_key_pair.pe_adm.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  tags = merge(local.tags, tomap({
    "Name" = "pe-server-${count.index}-${var.id}"
  }))

  lifecycle {
    ignore_changes = [tags["internalDNS"]]
  }

  # IMDSv2 only, set here so it doesn't depend on the AMI's defaults
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.primary_disk
    volume_type = "gp3"
    encrypted   = true
  }
}

# The biggest infrastructure difference to account for between large and extra
# large is externalization of the database service. Again given out assumption
# that extra large currently also means "with replica", we deploy two identical
# hosts in extra large but nothing in the other two architectures
resource "aws_instance" "psql" {
  ami           = data.aws_ami.ami.id
  instance_type = var.database_type
  # count is used to effectively "no-op" this resource in the event that we
  # deploy any architecture other than xlarge
  count                  = var.database_count
  key_name               = aws_key_pair.pe_adm.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  tags = merge(local.tags, tomap({
    "Name" = "pe-psql-${count.index}-${var.id}"
  }))

  lifecycle {
    ignore_changes = [tags["internalDNS"]]
  }

  # IMDSv2 only, set here so it doesn't depend on the AMI's defaults
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.database_disk
    volume_type = "gp3"
    encrypted   = true
  }
}

# The defining difference between standard and other architectures is the
# presence of load balanced instances with the sole duty of compiling catalogs
# for agents. A user chosen number of Compilers will be deployed in large and
# extra large but only ever zero can be deployed when the operating mode is set
# to standard
resource "aws_instance" "compiler" {
  ami           = data.aws_ami.ami.id
  instance_type = var.compiler_type
  # count is used to effectively "no-op" this resource in the event that we
  # deploy the standard architecture
  count                  = var.compiler_count
  key_name               = aws_key_pair.pe_adm.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  tags = merge(local.tags, tomap({
    "Name" = "pe-compiler-${count.index}-${var.id}"
  }))

  lifecycle {
    ignore_changes = [tags["internalDNS"]]
  }

  # IMDSv2 only, set here so it doesn't depend on the AMI's defaults
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.compiler_disk
    volume_type = "gp3"
    encrypted   = true
  }
}

# User requested number of nodes to serve as agent nodes for when this module is
# used to standup Puppet Enterprise for test and evaluation
resource "aws_instance" "node" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.small"
  count                  = var.node_count
  key_name               = aws_key_pair.pe_adm.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  tags = merge(local.tags, tomap({
    "Name" = "pe-node-${count.index}-${var.id}"
  }))

  lifecycle {
    ignore_changes = [tags["internalDNS"]]
  }

  # IMDSv2 only, set here so it doesn't depend on the AMI's defaults
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
  }
}
