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
  value = {
    aggregation             = module.aggregation.configuration_to_write.aggregation
    delivery_channel_target = module.delivery_channel_target_s3.configuration_to_write.delivery_channel_target
  }
}
