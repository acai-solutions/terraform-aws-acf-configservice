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
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.3.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
      configuration_aliases = [
        aws.aggregation,
        aws.delivery_channel_target_s3
      ]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "module_provider" = "ACAI GmbH",
      "module_name"     = "terraform-aws-acf-configservice",
      "module_source"   = "github.com/acai-solutions/terraform-aws-acf-configservice"
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA PREPARATION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ssm_parameter" "product_version" {
  #checkov:skip=CKV2_AWS_34: AWS SSM Parameter should be Encrypted not required for module version
  name           = "acai/acf/configservice/productversion"
  type           = "String"
  insecure_value = /*inject_version_start*/ "1.1.1" /*inject_version_end*/

  tags = local.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CALL SUB-MODULES
# ---------------------------------------------------------------------------------------------------------------------
module "aggregation" {
  source = "./aggregation"

  aws_config_settings = var.aws_config_settings
  resource_tags       = var.resource_tags
  providers = {
    aws = aws.aggregation
  }
}

module "delivery_channel_target_s3" {
  source = "./delivery-channel-target-s3"

  aws_config_settings = var.aws_config_settings
  resource_tags       = var.resource_tags
  providers = {
    aws = aws.delivery_channel_target_s3
  }
}
