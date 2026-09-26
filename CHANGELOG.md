# Changelog

## Unreleased

### Changed

- Bumped `hashicorp/aws` from 5.20.1 to 6.66.0. None of the breaking changes in the 6.0 upgrade guide apply to the resources and data sources this module uses. The `aws_ami` lookup already sets `owners`, which 6.0 now requires when `most_recent = true`.
- Bumped `hashicorp/random` from 3.1.0 to 3.9.1.
- Bumped `chriskuchin/hiera5` from 0.3.0 to 0.5.4. From 0.4.0 the provider looks for `hiera.yml` by default instead of `hiera.yaml`, so every lookup failed with "key not found". The provider block now sets `config = "${path.module}/hiera.yaml"`.
- Raised `required_version` from `>= 0.13` to `>= 1.5`. The module is tested with OpenTofu 1.12.
- Ran `tofu fmt -recursive`. This also rewrote the untyped `map` variable type to the equivalent `map(any)`.

### Not changed

- Input variables, resource addresses and outputs are the same, so existing pecdm tfvars and inventory mappings keep working.
- The default image stays `764336703387/AlmaLinux OS 8*`. AlmaLinux 8 is still supported and publishes current AMIs, which log in as `ec2-user`.
