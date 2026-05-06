# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


variable "iam_role_settings" {
  description = "Settings for IAM Roles."
  type = object({
    name                     = string
    path                     = optional(string, "/")
    permissions_boundary_arn = optional(string)
    aws_trustee_arns         = list(string)
  })

  validation {
    condition     = var.iam_role_settings.path == null ? true : can(regex("^/([^/]+(/[^/]+)*/?)?$", var.iam_role_settings.path))
    error_message = "Path value must start with '/' and can optionally end with '/', without containing consecutive '/' characters."
  }

  validation {
    condition     = var.iam_role_settings.permissions_boundary_arn == null ? true : can(regex("^arn:aws(-[a-z]+)*:iam::[0-9]{12}:policy/.+$", var.iam_role_settings.permissions_boundary_arn))
    error_message = "Permissions boundary ARN must be a valid IAM policy ARN."
  }
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
