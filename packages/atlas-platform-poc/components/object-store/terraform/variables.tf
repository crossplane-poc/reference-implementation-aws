################################################################################
# Identity
################################################################################
variable "animal" {
  description = "The product's UID. Second segment of every name this module creates."
  type        = string
}

variable "component" {
  description = "What this bucket is for — \"data\", \"statics\". The XR's own name."
  type        = string
}

variable "environment" {
  description = "dev | tst | uat | prd. Always the last segment of a name."
  type        = string

  validation {
    condition     = contains(["dev", "tst", "uat", "prd", "sb3"], var.environment)
    error_message = "environment must be one of: dev, tst, uat, prd, sb3."
  }
}

################################################################################
# Bucket Configuration
################################################################################
variable "retention_days" {
  description = "Expire objects after this many days. 0 means keep them forever."
  type        = number
  default     = 0
}

################################################################################
# Access Configuration
################################################################################
variable "access" {
  description = "Services granted access, and at what level. The IAM role name is derived."
  type        = list(object({ service = string, level = string }))
  default     = []

  validation {
    condition     = alltrue([for a in var.access : contains(["ro", "rw"], a.level)])
    error_message = "access[].level must be ro or rw."
  }
}
