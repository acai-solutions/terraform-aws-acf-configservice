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
# ¦ PROVIDER
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  alias  = "org_mgmt"
  assume_role {
    role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:role/${var.iam_role_name}"
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "workload_primary"
  assume_role {
    role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.workload}:role/${var.iam_role_name}"
  }
}

# Secondary region provider - only used on AWS commercial.
provider "aws" {
  region = length(var.secondary_regions) > 0 ? var.secondary_regions[0] : var.aws_region
  alias  = "workload_secondary"
  assume_role {
    role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.workload}:role/${var.iam_role_name}"
  }
}
