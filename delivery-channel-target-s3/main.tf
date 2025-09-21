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
      module_provider = "ACAI GmbH",
      module_name     = "terraform-aws-acf-configservice",
      module_source   = "github.com/acai-consulting/terraform-aws-acf-configservice",
      module_feature  = "delivery-chnl-target-s3",
      module_version  = /*inject_version_start*/ "1.1.0" /*inject_version_end*/
    }
  )
  s3_settings = var.aws_config_settings.delivery_channel_target.central_s3
  kms_cmk     = local.s3_settings.kms_cmk != null
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ KMS KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "aws_config_bucket_cmk" {
  count = local.kms_cmk ? 1 : 0

  description             = "Key for AWS Config objects in ${local.s3_settings.bucket_name}"
  deletion_window_in_days = local.s3_settings.kms_cmk.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.aws_config_bucket_cmk[0].json
  tags                    = local.resource_tags
}

# https://docs.aws.amazon.com/config/latest/developerguide/s3-kms-key-policy.html
data "aws_iam_policy_document" "aws_config_bucket_cmk" {
  #checkov:skip=CKV_AWS_109 : Ensure IAM policies does not allow permissions management / resource exposure without constraints
  #  Resource policy
  #checkov:skip=CKV_AWS_111 : Ensure IAM policies does not allow write access without constraints
  #  Resource policy
  #checkov:skip=CKV_AWS_356 : Ensure no IAM policies documents allow "*" as a statement's resource for restrictable actions
  #  Resource policy  
  count = local.kms_cmk ? 1 : 0

  source_policy_documents   = local.s3_settings.kms_cmk.additional_kms_cmk_grants
  override_policy_documents = local.s3_settings.kms_cmk.principal_permissions

  statement {
    sid    = "PrincipalPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAWSConfigServiceFromOrg"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = [data.aws_organizations_organization.current.id]
    }
  }
}

resource "aws_kms_alias" "aws_config_bucket_cmk" {
  count = local.kms_cmk ? 1 : 0

  name          = "alias/${local.s3_settings.kms_cmk.key_alias}"
  target_key_id = aws_kms_key.aws_config_bucket_cmk[0].key_id
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS CONFIG AGGREGATOR BUCKET
# ---------------------------------------------------------------------------------------------------------------------
#tfsec:ignore: AVD-AWS-0086 Severity: HIGH Message: No public access block so not blocking public acls
#  false-positive, see: resource "aws_s3_bucket_public_access_block" "aws_config_bucket"
#tfsec:ignore: AVD-AWS-0087 Severity: HIGH Message: No public access block so not blocking public policies
#  false-positive, see: resource "aws_s3_bucket_public_access_block" "aws_config_bucket"
#tfsec:ignore:AVD-AWS-0091 Severity: HIGH Message: No public access block so not blocking public acl
#  false-positive, see: resource "aws_s3_bucket_public_access_block" "aws_config_bucket"
resource "aws_s3_bucket" "aws_config_bucket" {
  #checkov:skip=CKV_AWS_144 : Ensure that S3 bucket has cross-region replication enabled - LOW
  #  No Cross-Region Bucket replication up to now
  #checkov:skip=CKV2_AWS_62 : S3 buckets do not have event notifications enabled - LOW
  #  Not needed 
  bucket        = local.s3_settings.bucket_name
  force_destroy = var.s3_delivery_bucket_force_destroy
  tags          = local.resource_tags
}

resource "aws_s3_bucket_public_access_block" "aws_config_bucket" {
  bucket                  = aws_s3_bucket.aws_config_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "aws_config_bucket" {
  bucket = aws_s3_bucket.aws_config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

#tfsec:ignore:AVD-AWS-0088 Severity: HIGH Message: Bucket does not have encryption enabled
#tfsec:ignore:AVD-AWS-0132 Severity: HIGH Message: Bucket does not encrypt data with a customer managed key. 
resource "aws_s3_bucket_server_side_encryption_configuration" "aws_config_bucket" {
  bucket = aws_s3_bucket.aws_config_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.kms_cmk ? "aws:kms" : "AES256"
      kms_master_key_id = local.kms_cmk ? aws_kms_key.aws_config_bucket_cmk[0].id : null
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "aws_config_bucket" {
  bucket = aws_s3_bucket.aws_config_bucket.id
  rule {
    id     = "Expiration"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    dynamic "transition" {
      for_each = local.s3_settings.days_to_glacier != -1 ? [1] : []
      content {
        days          = local.s3_settings.days_to_glacier
        storage_class = "GLACIER"
      }
    }
    expiration {
      days = local.s3_settings.days_to_expiration
    }
  }
}

resource "aws_s3_bucket_policy" "awsconfig_bucket" {
  bucket = aws_s3_bucket.aws_config_bucket.id
  policy = data.aws_iam_policy_document.awsconfig_bucket.json
}

data "aws_iam_policy_document" "awsconfig_bucket" {
  statement {
    sid    = "ConfigBucketListAndAcl"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.aws_config_bucket.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = [data.aws_organizations_organization.current.id]
    }
  }

  statement {
    sid    = "ConfigDeliveryWrites"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      format("%s/AWSLogs/*/Config/*", aws_s3_bucket.aws_config_bucket.arn),
      format("%s/*/AWSLogs/*/Config/*", aws_s3_bucket.aws_config_bucket.arn)
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = [data.aws_organizations_organization.current.id]
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS CONFIG AGGREGATOR ACCE LOGS BUCKET
# ---------------------------------------------------------------------------------------------------------------------
#tfsec:ignore:avd-aws-0089: Ensures S3 bucket logging is enabled for S3 buckets
#  This is the access-log bucket
#tfsec:ignore: AVD-AWS-0086 Severity: HIGH Message: No public access block so not blocking public acls
#  false-positive, see: resource "aws_s3_bucket_public_access_block" "log_access_bucket"
#tfsec:ignore: AVD-AWS-0087 Severity: HIGH Message: No public access block so not blocking public policies
#  false-positive, see: resource "aws_s3_bucket_public_access_block" "log_access_bucket"
#tfsec:ignore:AVD-AWS-0091 Severity: HIGH Message: No public access block so not blocking public acl
#  false-positive, see: resource "aws_s3_bucket_public_access_block" "log_access_bucket"
resource "aws_s3_bucket" "log_access_bucket" {
  #checkov:skip=CKV_AWS_144 : Ensure that S3 bucket has cross-region replication enabled - LOW
  #  No Cross-Region Bucket replication up to now
  #checkov:skip=CKV2_AWS_62 : S3 buckets do not have event notifications enabled - LOW
  #  Not needed 
  count         = local.s3_settings.bucket_access_logs_s3_id == null ? 1 : 0
  force_destroy = var.s3_delivery_bucket_force_destroy
  bucket        = "${aws_s3_bucket.aws_config_bucket.id}-access-logs"
  tags          = local.resource_tags
}

resource "aws_s3_bucket_public_access_block" "log_access_bucket" {
  count                   = local.s3_settings.bucket_access_logs_s3_id == null ? 1 : 0
  bucket                  = aws_s3_bucket.log_access_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "log_access_bucket" {
  count  = local.s3_settings.bucket_access_logs_s3_id == null ? 1 : 0
  bucket = aws_s3_bucket.log_access_bucket[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_logging" "config_bucket_logging" {
  bucket        = aws_s3_bucket.aws_config_bucket.id
  target_bucket = local.s3_settings.bucket_access_logs_s3_id == null ? aws_s3_bucket.log_access_bucket[0].id : local.s3_settings.bucket_access_logs_s3_id
  target_prefix = "logs/${aws_s3_bucket.aws_config_bucket.id}/"
}

#tfsec:ignore:AVD-AWS-0088 Severity: HIGH Message: Bucket does not have encryption enabled
#tfsec:ignore:AVD-AWS-0132 Severity: HIGH Message: Bucket does not encrypt data with a customer managed key. 
resource "aws_s3_bucket_server_side_encryption_configuration" "log_access_bucket" {
  count  = local.s3_settings.bucket_access_logs_s3_id == null ? 1 : 0
  bucket = aws_s3_bucket.log_access_bucket[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.kms_cmk ? "aws:kms" : "AES256"
      kms_master_key_id = local.kms_cmk ? aws_kms_key.aws_config_bucket_cmk[0].id : null
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_access_bucket" {
  count  = local.s3_settings.bucket_access_logs_s3_id == null ? 1 : 0
  bucket = aws_s3_bucket.log_access_bucket[0].id
  rule {
    id     = "access-log-retention"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    dynamic "transition" {
      for_each = local.s3_settings.days_to_glacier != -1 ? [1] : []
      content {
        days          = local.s3_settings.days_to_glacier
        storage_class = "GLACIER"
      }
    }
    expiration {
      days = local.s3_settings.days_to_expiration
    }
  }
}
