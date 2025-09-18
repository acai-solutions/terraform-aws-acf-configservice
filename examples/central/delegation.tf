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
# ¦ DELEGATIONS
# ---------------------------------------------------------------------------------------------------------------------
data "aws_region" "org_mgmt" {
  provider = aws.org_mgmt
}

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
  #checkov:skip=CKV_AWS_50
  source = "git::https://github.com/acai-consulting/terraform-aws-acf-org-delegation.git//modules/preprocess-data?ref=1.0.3"

  primary_aws_region = local.regions_settings.primary_region
  delegations        = local.delegations
}


#tfsec:ignore:AVD-AWS-0066
module "delegation_euc1" {
  #checkov:skip=CKV_TF_1: Currently version-tags are used
  #checkov:skip=CKV_AWS_50  
  source = "git::https://github.com/acai-consulting/terraform-aws-acf-org-delegation.git?ref=1.0.3"

  primary_aws_region = module.delegation_preprocess_data.is_primary_region[data.aws_region.org_mgmt.name]
  delegations        = module.delegation_preprocess_data.delegations_by_region[data.aws_region.org_mgmt.name]
  providers = {
    aws = aws.org_mgmt
  }
}
