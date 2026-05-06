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
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_partition" "current" { provider = aws.org_mgmt }


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
