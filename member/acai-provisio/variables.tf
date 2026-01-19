# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


variable "provisio_settings" {
  description = "ACAI PROVISIO settings"
  type = object({
    package_name         = optional(string, "aws-config")
    override_module_name = optional(string, null)
    terraform_version    = optional(string, ">= 1.3.10")
    provider_aws_version = optional(string, ">= 4.00")
    target_regions = object({
      primary_region    = string
      secondary_regions = list(string)
    })
    import_resources = optional(bool, false)
  })
  validation {
    condition     = !contains(var.provisio_settings.target_regions.secondary_regions, var.provisio_settings.target_regions.primary_region)
    error_message = "The primary region must not be included in the secondary regions."
  }
}

variable "aws_config_settings" {
  description = "Account hardening settings"
  type = object({
    aggregation = object({
      aggregation_account_id = string
    })
    delivery_channel_target = object({
      central_s3 = optional(object({
        bucket_name = string
        kms_cmk = optional(object({
          arn = optional(string, "")
        }), null)
      }), null)
    })
    account_baseline = object({
      # compliant with CIS AWS 
      iam_role_name          = optional(string, "aws-config-recorder-role")
      iam_role_path          = optional(string, "/")
      recorder_name          = optional(string, "aws-config-recorder")
      delivery_channel_name  = optional(string, "aws-config-recorder-delivery-channel")
      exclude_resource_types = optional(list(string), []) #"List of AWS resource types to exclude from recording (e.g., AWS::EC2::Instance)"
    })
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMMON
# ---------------------------------------------------------------------------------------------------------------------
variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
