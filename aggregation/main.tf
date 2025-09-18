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
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "module_provider" = "ACAI GmbH",
      "module_name"     = "terraform-aws-acf-configservice",
      "module_source"   = "github.com/acai-consulting/terraform-aws-acf-configservice",
      "module_feature"  = "aggregation",
      "module_version"  = /*inject_version_start*/ "1.0.3" /*inject_version_end*/
    }
  )
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS CONFIG AGGREGATOR ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "aws_config_aggregator_role" {
  name               = var.aws_config_settings.aggregation.aggregator_role_name
  assume_role_policy = data.aws_iam_policy_document.aws_config_aggregator_role_trust.json
}

data "aws_iam_policy_document" "aws_config_aggregator_role_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "aws_config_aggregator_role_permissions" {
  role = aws_iam_role.aws_config_aggregator_role.name
  # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSConfigRoleForOrganizations.html
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS CONFIG AGGREGATOR
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_config_configuration_aggregator" "aws_config_aggregator" {
  name = var.aws_config_settings.aggregation.aggregator_name
  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.aws_config_aggregator_role.arn
  }
  depends_on = [
    aws_iam_role_policy_attachment.aws_config_aggregator_role_permissions
  ]
}
