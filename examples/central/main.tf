# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


# ---------------------------------------------------------------------------------------------------------------------
# ¦ VERSIONS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.3.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_partition" "current" { provider = aws.org_mgmt }

data "aws_caller_identity" "org_mgmt" {
  provider = aws.org_mgmt
}

data "aws_caller_identity" "aggregation" {
  provider = aws.core_security
}

data "aws_caller_identity" "logging" {
  provider = aws.core_logging
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  regions_settings = {
    primary_region    = var.aws_region
    secondary_regions = var.secondary_regions
  }
  aws_config_settings = {
    aggregation = {
      aggregator_name      = "aws-config-aggregator"
      aggregator_role_name = "aws-config-aggregator-role"
    }
    delivery_channel_target = {
      central_s3 = {
        bucket_name        = format("aws-config-logs-%s", data.aws_caller_identity.logging.account_id)
        days_to_glacier    = 90
        days_to_expiration = 360
        kms_cmk = var.bucket_encryption == "CMK" ? {
          key_alias               = "aws-config-recorder-logs-key"
          deletion_window_in_days = 30
        } : null
      }
    }
    account_baseline = {
      iam_role_name         = "aws-config-recorder-role"
      iam_role_path         = "/"
      recorder_name         = "aws-config-recorder"
      delivery_channel_name = "aws-config-recorder-delivery-channel"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DELEGATION (org-mgmt)
# ---------------------------------------------------------------------------------------------------------------------
locals {
  delegations = [
    {
      regions            = concat([local.regions_settings.primary_region], local.regions_settings.secondary_regions)
      aggregation_region = local.regions_settings.primary_region
      service_principal  = "config.amazonaws.com"
      target_account_id  = data.aws_caller_identity.aggregation.account_id
    }
  ]
}

#tfsec:ignore:AVD-AWS-0066
module "delegation_preprocess_data" {
  #checkov:skip=CKV_TF_1: Currently version-tags are used
  source = "git::https://github.com/acai-solutions/terraform-aws-acf-org-delegation.git//modules/preprocess-data?ref=1.1.0"

  primary_aws_region = local.regions_settings.primary_region
  delegations        = local.delegations
}

#tfsec:ignore:AVD-AWS-0066
module "delegation_primary" {
  #checkov:skip=CKV_TF_1: Currently version-tags are used
  source = "git::https://github.com/acai-solutions/terraform-aws-acf-org-delegation.git?ref=1.1.0"

  primary_aws_region = module.delegation_preprocess_data.is_primary_region[var.aws_region]
  delegations        = module.delegation_preprocess_data.delegations_by_region[var.aws_region]
  providers = {
    aws = aws.delegation
  }
  depends_on = [module.create_provisioner_delegation]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ MODULE
# ---------------------------------------------------------------------------------------------------------------------
module "aggregation" {
  source = "../../aggregation"

  aws_config_settings = local.aws_config_settings
  providers = {
    aws = aws.aggregation
  }
  depends_on = [
    module.delegation_primary,
    module.create_provisioner_aggregation,
  ]
}

module "s3_delivery_channel" {
  source = "../../delivery-channel-target-s3"

  aws_config_settings              = local.aws_config_settings
  s3_delivery_bucket_force_destroy = true
  providers = {
    aws = aws.delivery
  }
  depends_on = [module.create_provisioner_delivery]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ MEMBER PACKAGE RENDERING
# ---------------------------------------------------------------------------------------------------------------------
locals {
  member_input = merge(local.aws_config_settings,
    {
      aggregation = merge(local.aws_config_settings.aggregation, {
        aggregation_account_id = data.aws_caller_identity.aggregation.account_id
      })
    },
    {
      delivery_channel_target = {
        central_s3 = merge(local.aws_config_settings.delivery_channel_target.central_s3, {
          kms_cmk = merge(try(local.aws_config_settings.delivery_channel_target.central_s3.kms_cmk, {}), {
            arn = try(module.s3_delivery_channel.configuration_to_write.delivery_channel_target.central_s3.kms_cmk.arn, "")
          })
        })
      }
    }
  )
}

module "member_files" {
  source = "../../member/acai-provisio"

  provisio_settings = {
    target_regions = local.regions_settings
  }
  aws_config_settings = local.member_input
}

# Loop through the map and create a file for each entry
resource "local_file" "package_files" {
  for_each = module.member_files.package_files

  filename = "${path.module}/../member-provisio/rendered/${each.key}"
  content  = each.value
}
