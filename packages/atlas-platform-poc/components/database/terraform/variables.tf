################################################################################
# Identity
################################################################################
variable "animal" {
  description = "The product's UID. Second segment of every name, and the database name."
  type        = string
}

variable "component" {
  description = "What this database is for — usually just \"db\". The XR's own name."
  type        = string
}

variable "environment" {
  description = "dev | tst | uat | prd. Decides backup retention and deletion protection, and names the cluster."
  type        = string

  validation {
    condition     = contains(["dev", "tst", "uat", "prd", "sb3"], var.environment)
    error_message = "environment must be one of: dev, tst, uat, prd, sb3."
  }
}

################################################################################
# Cluster Configuration
################################################################################
variable "size" {
  description = "small | medium | large. See locals.tf for what each buys in ACUs."
  type        = string
  default     = "small"

  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "size must be one of: small, medium, large."
  }
}

variable "engine_version" {
  description = "Aurora PostgreSQL version. A platform decision, the same in every environment."
  type        = string
  default     = "16.11"
}

################################################################################
# IAM Authentication Configuration
################################################################################
variable "access" {
  description = "Services granted rds-db:connect as iam_user, by name — no lookup needed."
  type        = list(string)
  default     = []
}

variable "admin_access" {
  description = <<-EOT
    IAM role names granted the admin_iam database user. Full role names — nothing is prefixed
    or expanded.
  EOT
  type        = list(string)
  default     = []
}

################################################################################
# Bootstrap Lambda Configuration
################################################################################
variable "bootstrap_image" {
  description = "The database-roles Lambda image, from the shared CloudTools registry."
  type        = string
  default     = "525426937140.dkr.ecr.eu-west-1.amazonaws.com/utils/bootstrap-db-lambda:0.1.10"
}
