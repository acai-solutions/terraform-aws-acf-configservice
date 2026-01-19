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
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.0"
      configuration_aliases = []
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
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
    primary_region    = "eu-central-1"
    secondary_regions = ["us-east-2"]
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
# ¦ MODULE
# ---------------------------------------------------------------------------------------------------------------------
module "aggregation" {
  source = "../../aggregation"

  aws_config_settings = local.aws_config_settings
  providers = {
    aws = aws.core_security
  }
  depends_on = [
    module.delegation_euc1
  ]
}

module "s3_delivery_channel" {
  source = "../../delivery-channel-target-s3"

  aws_config_settings = local.aws_config_settings

  s3_delivery_bucket_force_destroy = true
  providers = {
    aws = aws.core_logging
  }
}


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

  filename = "${path.module}/../member-provisio/rendered/${each.key}" # Each key becomes the filename
  content  = each.value                                               # Each value becomes the file content
}
