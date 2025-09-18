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
data "aws_organizations_organization" "current" {}

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
      "module_feature"  = "delivery-chnl-target-s3",
      "module_version"  = /*inject_version_start*/ "1.0.3" /*inject_version_end*/
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OPTIONAL BUCKET - KMS KEY
# ---------------------------------------------------------------------------------------------------------------------
locals {
  kms_cmk = var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk == null ? false : true
  member_iam_rolename_with_path = replace(
    format("arn:aws:iam::*:role/%s%s", var.aws_config_settings.account_baseline.iam_role_path, var.aws_config_settings.account_baseline.iam_role_name),
    "////", "/"
  )
}

resource "aws_kms_key" "aws_config_bucket_cmk" {
  count = local.kms_cmk ? 1 : 0

  description             = "Encryption key for object uploads to S3 bucket ${var.aws_config_settings.delivery_channel_target.central_s3.bucket_name}"
  deletion_window_in_days = var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.aws_config_bucket_cmk[0].json
  tags                    = var.resource_tags
}

# https://docs.aws.amazon.com/config/latest/developerguide/s3-kms-key-policy.html
data "aws_iam_policy_document" "aws_config_bucket_cmk" {
  count = local.kms_cmk ? 1 : 0

  # enable IAM in logging account
  source_policy_documents = var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk.additional_kms_cmk_grants != null ? [var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk.additional_kms_cmk_grants] : null

  dynamic "statement" {
    for_each = var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk.enable_iam_user_permissions != false ? [1] : []
    content {
      sid    = "Enable IAM User Permissions"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }

      actions   = ["kms:*"]
      resources = ["*"]
    }
  }

  # allow member roles
  statement {
    sid    = "AWSConfigKMSPolicy"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values = [
        data.aws_organizations_organization.current.id
      ]
    }
  }
}

resource "aws_kms_alias" "aws_config_bucket_cmk" {
  count = local.kms_cmk ? 1 : 0

  name          = "alias/${var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk.key_alias}"
  target_key_id = aws_kms_key.aws_config_bucket_cmk[0].key_id
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS CONFIG AGGREGATOR BUCKET
# ---------------------------------------------------------------------------------------------------------------------
#tfsec:ignore:avd-aws-0089
resource "aws_s3_bucket" "aws_config_bucket" {
  #checkov:skip=CKV_AWS_144 : No Cross-Region Bucket replication 
  #checkov:skip=CKV_AWS_145  
  #checkov:skip=CKV2_AWS_62  
  #checkov:skip=CKV_AWS_19  
  #checkov:skip=CKV_AWS_18 // TODO: add access logs  
  bucket        = var.aws_config_settings.delivery_channel_target.central_s3.bucket_name
  force_destroy = var.s3_delivery_bucket_force_destroy
  tags          = local.resource_tags
}

resource "aws_s3_bucket_versioning" "aws_config_bucket" {
  bucket = aws_s3_bucket.aws_config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_config_bucket" {
  bucket = aws_s3_bucket.aws_config_bucket.id

  dynamic "rule" {
    for_each = local.kms_cmk == true ? [1] : []
    content {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.aws_config_bucket_cmk[0].id
        sse_algorithm     = "aws:kms"
      }
    }
  }
  dynamic "rule" {
    for_each = local.kms_cmk == false ? [1] : []
    content {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "aws_config_bucket" {
  #checkov:skip=CKV_AWS_300 : No Multipart Upload
  bucket = aws_s3_bucket.aws_config_bucket.id
  rule {
    id     = "Expiration"
    status = "Enabled"
    expiration {
      days = var.aws_config_settings.delivery_channel_target.central_s3.bucket_days_to_expiration
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "aws_config_bucket" {
  bucket                  = aws_s3_bucket.aws_config_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_policy" "awsconfig_bucket" {
  bucket = resource.aws_s3_bucket.aws_config_bucket.id
  policy = data.aws_iam_policy_document.awsconfig_bucket.json
}

data "aws_iam_policy_document" "awsconfig_bucket" {
  statement {
    sid    = "AWSConfigBucketPermissionsCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [resource.aws_s3_bucket.aws_config_bucket.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values = [
        data.aws_organizations_organization.current.id
      ]
    }
  }
  statement {
    sid    = "AWSConfigBucketDelivery"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      format("%s/AWSLogs/*/Config/*", resource.aws_s3_bucket.aws_config_bucket.arn),
      format("%s/*/AWSLogs/*/Config/*", resource.aws_s3_bucket.aws_config_bucket.arn)
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values = [
        data.aws_organizations_organization.current.id
      ]
    }
  }
}
