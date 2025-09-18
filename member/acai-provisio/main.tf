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
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMPILE PROVISIO PACKAGES
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = templatefile("${path.module}/templates/tags.tf.tftpl", {
    map_of_tags = merge(
      var.resource_tags,
      {
        "module_provider" = "ACAI GmbH",
        "module_name"     = "terraform-aws-acf-configservice",
        "module_source"   = "github.com/acai-consulting/terraform-aws-acf-configservice",
        "module_feature"  = "member",
        "module_version"  = /*inject_version_start*/ "1.0.3" /*inject_version_end*/
      }
    )
  })

  delivery_target_s3 = try(var.aws_config_settings.delivery_channel_target.central_s3, null) != null
  bucket_kms_cmk_arn = try(var.aws_config_settings.delivery_channel_target.central_s3.kms_cmk.arn, "")
  all_regions        = distinct(concat([var.provisio_settings.provisio_regions.primary_region], var.provisio_settings.provisio_regions.secondary_regions))
  tf_module_name     = replace(var.provisio_settings.override_module_name == null ? var.provisio_settings.provisio_package_name : var.provisio_settings.override_module_name, "-", "_")

  provisio_package_files = merge(
    var.provisio_settings.import_resources ? ({
      "import.part" = templatefile("${path.module}/templates/import.part.tftpl", {
        tf_module_name                  = local.tf_module_name
        primary_region                  = var.provisio_settings.provisio_regions.primary_region
        all_regions                     = local.all_regions
        config_iam_role_name            = var.aws_config_settings.account_baseline.iam_role_name
        config_recorder_name            = var.aws_config_settings.account_baseline.recorder_name
        config_s3_delivery              = local.delivery_target_s3
        config_s3_delivery_channel_name = var.aws_config_settings.account_baseline.delivery_channel_name
      })
      }) : ({
      "import.part" = ""
    }),
    {
      "main.tf" = templatefile("${path.module}/templates/main.tf.tftpl", {
        primary_region                         = var.provisio_settings.provisio_regions.primary_region
        secondary_regions                      = var.provisio_settings.provisio_regions.secondary_regions
        aggregation_account_id                 = var.aws_config_settings.aggregation.aggregation_account_id
        config_iam_role_name                   = var.aws_config_settings.account_baseline.iam_role_name
        config_iam_role_path                   = var.aws_config_settings.account_baseline.iam_role_path
        config_recorder_name                   = var.aws_config_settings.account_baseline.recorder_name
        config_delivery_channel_name           = var.aws_config_settings.account_baseline.delivery_channel_name
        config_recorder_exclude_resource_types = var.aws_config_settings.account_baseline.exclude_resource_types
        config_s3_delivery                     = local.delivery_target_s3
        config_s3_delivery_bucket_name         = local.delivery_target_s3 ? var.aws_config_settings.delivery_channel_target.central_s3.bucket_name : ""
        config_s3_delivery_bucket_kms_cmk_arn  = local.bucket_kms_cmk_arn
        resource_tags                          = local.resource_tags
      })
      "requirements.tf" = templatefile("${path.module}/templates/requirements.tf.tftpl", {
        all_regions          = local.all_regions
        terraform_version    = ">= 1.3.10",
        provider_aws_version = ">= 4.00",
      })
    }
  )
}
