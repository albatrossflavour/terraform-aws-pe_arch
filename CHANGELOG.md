# Changelog

## Unreleased

### Added

- Outputs for layers built beside the deployment: `vpc_id`, `subnet_ids`, `security_group_id`, `private_zone_id`, `public_zone_id`, `domain_name`, `deployment_id` and `key_name`.
- `operator_ports` sets which TCP ports `firewall_allow` can reach. The default is the previous fixed list (22, 443, 4433, 8081, 8143, 8170). Every node shares one security group, so an added port is open on all of them.
- Split-horizon DNS when `domain_name` is set. A private Route 53 zone attached to the VPC holds every node's private address, and `puppet.<domain_name>` points at the compiler load balancer (an alias record) or, without one, the primary. Set `public_zone_id` to an existing public zone for the domain and the nodes' public addresses are published there too. `puppet` stays private: the load balancer is internal and agents sit inside the VPC.
- With `domain_name` set, certnames describe roles instead of carrying the deployment ID: `primary-1`, `replica-1`, `postgres-1` and `postgres-2`, `compiler-N` and `agent-N`. The `console` output becomes `primary-1.<domain_name>` and `pool` becomes `puppet.<domain_name>`, which pecdm passes to peadm as the compiler pool address, so it lands in the primary's and compilers' `dns_alt_names`. Names no longer change between builds, so only one deployment per domain.

### Fixed

- A newer AMI matching `instance_image` no longer replaces running nodes. The instances look the image up with `most_recent = true` and didn't ignore changes to it, so the next plan after a new release (AlmaLinux publishes regularly) proposed replacing every node in the deployment.

### Security

- The security group no longer opens every port to `firewall_allow`. Those ranges now reach only SSH (22), the console (443), RBAC (4433), PuppetDB queries (8081), orchestrator (8143) and Code Manager (8170). Traffic from within the VPC is still unrestricted, because the NLB has no security group and its health checks come from VPC addresses.
- Removed the hardcoded `10.128.0.0/9` from the allowed ranges. It is Google Cloud's default network range, inherited from the GCP module, and here it opened every port to half of `10.0.0.0/8`.
- Root volumes are encrypted `gp3` (were unencrypted `gp2`). The account's default encryption setting no longer matters.
- Instances require IMDSv2 with a hop limit of 1. This was previously left to the AMI: AlmaLinux sets it, but other images may not.

### Changed

- Bumped `hashicorp/aws` from 5.20.1 to 6.66.0. None of the breaking changes in the 6.0 upgrade guide apply to the resources and data sources this module uses. The `aws_ami` lookup already sets `owners`, which 6.0 now requires when `most_recent = true`.
- Bumped `hashicorp/random` from 3.1.0 to 3.9.1.
- Bumped `chriskuchin/hiera5` from 0.3.0 to 0.5.4. From 0.4.0 the provider looks for `hiera.yml` by default instead of `hiera.yaml`, so every lookup failed with "key not found". The provider block now sets `config = "${path.module}/hiera.yaml"`.
- Raised `required_version` from `>= 0.13` to `>= 1.5`. The module is tested with OpenTofu 1.12.
- Ran `tofu fmt -recursive`. This also rewrote the untyped `map` variable type to the equivalent `map(any)`.

### Not changed

- Input variables, resource addresses and outputs are the same, so existing pecdm tfvars and inventory mappings keep working.
- The default image stays `764336703387/AlmaLinux OS 8*`. AlmaLinux 8 is still supported and publishes current AMIs, which log in as `ec2-user`.
