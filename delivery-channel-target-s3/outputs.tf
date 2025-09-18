# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


output "configuration_to_write" {
  value = local.kms_cmk ? {
    delivery_channel_target = {
      central_s3 = {
        kms_cmk = {
          arn = aws_kms_key.aws_config_bucket_cmk[0].arn
        }
      }
    }
  } : {}
}