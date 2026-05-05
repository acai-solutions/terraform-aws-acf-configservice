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
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CREATE PROVISIONER
# ---------------------------------------------------------------------------------------------------------------------
module "create_provisioner" {
  source = "../../cicd-principals/terraform/member"

  iam_role_settings = {
    name = "configservice_member_cicd_provisioner"
    aws_trustee_arns = [
      "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.workload_primary
  }
}

# Region-pinned providers, each assuming the member provisioner role inside the workload account.
provider "aws" {
  region = var.aws_region
  alias  = "workload_member_primary"
  assume_role {
    role_arn = module.create_provisioner.iam_role_arn
  }
}

provider "aws" {
  region = length(var.secondary_regions) > 0 ? var.secondary_regions[0] : var.aws_region
  alias  = "workload_member_secondary"
  assume_role {
    role_arn = module.create_provisioner.iam_role_arn
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ MODULE - apply the rendered package produced by the central example
# ---------------------------------------------------------------------------------------------------------------------
module "member" {
  source = "./rendered"

  providers = {
    aws              = aws.workload_member_primary
    aws.eu_central_1 = aws.workload_member_primary
    aws.us_east_2    = aws.workload_member_secondary
  }

  depends_on = [module.create_provisioner]
}
