# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


output "member_settings" {
  description = "Settings to be provided to render member files."
  value       = local.member_input
}

output "member_files" {
  description = "Rendered member files."
  value       = module.member_files
}
