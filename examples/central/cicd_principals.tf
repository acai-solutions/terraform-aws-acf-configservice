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
# ¦ CREATE PROVISIONERS
# ---------------------------------------------------------------------------------------------------------------------
module "create_provisioner_aggregation" {
  source = "../../cicd-principals/terraform/aggregation"

  iam_role_settings = {
    name = "configservice_aggregation_cicd_provisioner"
    aws_trustee_arns = [
      "arn:${data.aws_partition.current.partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.core_security
  }
}

module "create_provisioner_delivery" {
  source = "../../cicd-principals/terraform/delivery"

  iam_role_settings = {
    name = "configservice_delivery_cicd_provisioner"
    aws_trustee_arns = [
      "arn:${data.aws_partition.current.partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.core_logging
  }
}

module "create_provisioner_delegation" {
  source = "../../cicd-principals/terraform/delegation"

  iam_role_settings = {
    name = "configservice_delegation_cicd_provisioner"
    aws_trustee_arns = [
      "arn:${data.aws_partition.current.partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.org_mgmt
  }
}

# Region-pinned providers, each assuming the corresponding provisioner role.
provider "aws" {
  region = var.aws_region
  alias  = "aggregation"
  assume_role {
    role_arn = module.create_provisioner_aggregation.iam_role_arn
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "delivery"
  assume_role {
    role_arn = module.create_provisioner_delivery.iam_role_arn
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "delegation"
}