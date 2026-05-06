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
}

provider "aws" {
  region = var.aws_region
  alias  = "core_logging"
  assume_role {
    role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.core_logging}:role/${var.iam_role_name}"
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "core_security"
  assume_role {
    role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.core_security}:role/${var.iam_role_name}"
  }
}
