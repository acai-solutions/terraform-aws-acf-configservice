# terraform-aws-acf-configservice Terraform module

<!-- LOGO -->
<a href="https://acai.gmbh">    
  <img src="https://github.com/acai-solutions/acai.public/raw/main/logo/logo_github_readme.png" alt="acai logo" title="ACAI" align="right" height="75" />
</a>

<!-- SHIELDS -->
[![Maintained by acai.gmbh][acai-shield]][acai-url]
[![documentation][acai-docs-shield]][acai-docs-url]  
![module-version-shield]
![terraform-version-shield]  
![trivy-shield]
![checkov-shield]

<!-- BEGIN_ACAI_DOCS -->
This [Terraform][terraform-url] module automates the deployment of the central and de-central resources for AWS Config.

This module is featuring:

- Central AWS Config Aggregator
- Central AWS Config Logging
- AWS Config Member Resources (via ACAI PROVISIO)

![architecture][architecture]

## Usage

Define the AWS Config settings:

```hcl
# ¦ security - aws_config
aws_config = {
  aggregation = {
    aggregator_name        = "aws-config-aggregator"
    aggregator_role_name   = "aws-config-aggregator-role"
    aggregation_account_id = try(var.aws_config_configuration.aggregation.aggregation_account_id, local.core_accounts.security) 
  }
  delivery_channel_target = {    
    central_s3 = {
      bucket_name               = format("aws-config-logs-%s", local.core_accounts.logging)
      kms_cmk = {
        key_alias                   = "aws-config-recorder-logs-key"
        deletion_window_in_days     = 30
        additional_kms_cmk_grants   = ""
        enable_iam_user_permissions = true
        arn = try(var.aws_config_configuration.delivery_channel_target.central_s3.kms_cmk.arn, null)
      }
      bucket_days_to_glacier    = 90
      bucket_days_to_expiration = 360
    }
  }
  account_baseline = {
    iam_role_name         = "aws-config-recorder-role"
    iam_role_path         = "/"
    recorder_name         = "aws-config-recorder"
    delivery_channel_name = "aws-config-recorder-delivery-channel"
  }
}
```

Provision the central aggregator to e.g. Core Security:

```hcl
module "aggregation" {
  source = "git::https://github.com/acai-solutions/terraform-aws-acf-configservice.git//aggregation?ref=1.0.3"

  aws_config_settings = local.aws_config_settings
  providers = {
    aws = aws.core_security
  }
}
```

Provision the central delivery bucket to e.g. Core Logging:

```hcl
module "s3_delivery_channel" {
  source = "git::https://github.com/acai-solutions/terraform-aws-acf-configservice.git//delivery-channel-target-s3?ref=1.0.3"

  aws_config_settings = local.aws_config_settings
  providers = {
    aws = aws.core_logging
  }
}
```

Provision the member resources with ACAI PROVISIO:

```hcl
module "aws_config_service" {
  source = "git::https://github.com/acai-solutions/terraform-aws-acf-configservice.git//member/acai-provisio?ref=1.0.3"

  provisio_settings = {
    provisio_regions = local.regions_settings
  }
  aws_config_settings = local.aws_config_settings
}

locals {
  package_specification = [
    module.aws_config_service,
  ]
  package_deployment = [
    {
      deployment_name = "account-baselining-default"
      provisio_package_names = [
        module.aws_config_service.provisio_package_name,
      ]
    }
  ]
}

module "provisio_core_baseling" {
  source = "git::https://github.com/acai-solutions/terraform-aws-acai-provisio//baseline?ref=1.0.0"

  provisio_baseline_specification = {
    package_specification = local.package_specification
    package_deployment    = local.package_deployment
  }
  provisio_regions   = {
    primary_region    = "eu-central-1"
    secondary_regions = [
      "eu-west-1",
      "us-east-1"
    ]
  }
  provisio_bucket_id = module.provisio_core.provisio_configuration_to_write.core_provisio.provisio_bucket_id
  providers = {
    aws = aws.core_baselining
  }
}
```
<!-- END_ACAI_DOCS -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aggregation"></a> [aggregation](#module\_aggregation) | ./aggregation | n/a |
| <a name="module_delivery_channel_target_s3"></a> [delivery\_channel\_target\_s3](#module\_delivery\_channel\_target\_s3) | ./delivery-channe-target-s3 | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_config_settings"></a> [aws\_config\_settings](#input\_aws\_config\_settings) | AWS Config- Aggregation Settings. | <pre>object({<br/>    aggregation = optional(object({<br/>      aggregator_name      = optional(string, "aws-config-aggregator")<br/>      aggregator_role_name = optional(string, "aws-config-aggregator-role")<br/>      }),<br/>      {<br/>        aggregator_name      = "aws-config-aggregator"<br/>        aggregator_role_name = "aws-config-aggregator-role"<br/>    })<br/>    delivery_channel_target = object({<br/>      central_s3 = object({<br/>        bucket_name = string<br/>        kms_cmk = optional(object({<br/>          key_alias                   = optional(string, "aws-config-recorder-logs-key")<br/>          deletion_window_in_days     = optional(number, 30)<br/>          additional_kms_cmk_grants   = string<br/>          enable_iam_user_permissions = optional(bool, true)<br/>        }), null)<br/>        bucket_days_to_glacier    = optional(number, 30)<br/>        bucket_days_to_expiration = optional(number, 180)<br/>      })<br/>    })<br/>    account_baseline = object({<br/>      iam_role_name          = optional(string, "aws-config-recorder-role")<br/>      iam_role_path          = optional(string, "/")<br/>      recorder_name          = optional(string, "aws-config-recorder")<br/>      delivery_channel_name  = optional(string, "aws-config-recorder-delivery-channel")<br/>      exclude_resource_types = optional(list(string), []) # List of AWS resource types to exclude from recording (e.g., AWS::EC2::Instance)<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources in this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configuration_to_write"></a> [configuration\_to\_write](#output\_configuration\_to\_write) | n/a |
<!-- END_TF_DOCS -->

<!-- AUTHORS -->
## Authors

This module is maintained by [ACAI GmbH][acai-url].

<!-- LICENSE -->
## License

See [LICENSE][license-url] for full details.

<!-- COPYRIGHT -->
<br />
<br />
<p align="center">Copyright &copy; 2024, 2025 ACAI GmbH</p>

<!-- MARKDOWN LINKS & IMAGES -->
[acai-shield]: https://img.shields.io/badge/maintained_by-acai.gmbh-CB224B?style=flat
[acai-docs-shield]: https://img.shields.io/badge/documentation-docs.acai.gmbh-CB224B?style=flat
[acai-url]: https://acai.gmbh
[acai-docs-url]: https://docs.acai.gmbh
[module-version-shield]: https://img.shields.io/badge/module_version-1.0.3-CB224B?style=flat
[module-release-url]: https://github.com/acai-solutions/terraform-aws-acf-configservice/releases
[terraform-version-shield]: https://img.shields.io/badge/tf-%3E%3D1.3.10-blue.svg?style=flat&color=blueviolet
[trivy-shield]: https://img.shields.io/badge/trivy-passed-green
[checkov-shield]: https://img.shields.io/badge/checkov-passed-green
[architecture]: ./docs/terraform-aws-acf-configservice.png
[license-url]: https://github.com/acai-solutions/terraform-aws-acf-configservice/tree/main/LICENSE.md
[terraform-url]: https://www.terraform.io
[example-central-url]: ./examples/central
[example-member-provisio-rendered-url]: ./examples/member-provisio/rendered
[example-member-provisio]: ./examples/member-provisio
