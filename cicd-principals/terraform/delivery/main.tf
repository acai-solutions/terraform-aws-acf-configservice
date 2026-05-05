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
      source                = "hashicorp/aws"
      version               = ">= 5.30"
      configuration_aliases = []
    }
  }
}

data "aws_partition" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ IAM ROLE - DELIVERY CHANNEL S3 PROVISIONER (core-logging)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "cicd_principal" {
  name                 = var.iam_role_settings.name
  path                 = var.iam_role_settings.path
  permissions_boundary = var.iam_role_settings.permissions_boundary_arn
  description          = "IAM Role used to provision the AWS Config Delivery Channel S3 bucket (core-logging account)"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_policy.json
  tags                 = var.resource_tags
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = var.iam_role_settings.aws_trustee_arns
    }
  }
}

resource "aws_iam_role_policy" "delivery" {
  name   = "ConfigDeliveryChannelProvisioning"
  role   = aws_iam_role.cicd_principal.id
  policy = data.aws_iam_policy_document.delivery.json
}

#tfsec:ignore:AVD-AWS-0057
data "aws_iam_policy_document" "delivery" {
  #checkov:skip=CKV_AWS_111
  #checkov:skip=CKV_AWS_356
  #checkov:skip=CKV_AWS_109
  statement {
    sid    = "OrganizationsRead"
    effect = "Allow"
    actions = [
      "organizations:DescribeOrganization",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "S3BucketManagement"
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::*",
    ]
  }
  statement {
    sid    = "KMSManagement"
    effect = "Allow"
    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }
}
