################################################################################
# Identity
################################################################################
variable "animal" {
  description = "The product's UID. The XR's own name, and its namespace."
  type        = string

  validation {
    condition     = can(regex("^([a-z]{3,9}-)?[a-z]{3,10}$", var.animal))
    error_message = "animal must be <adjective>-<animal>, or a bare animal for a UID predating adjectives."
  }
}

variable "environment" {
  description = "dev | tst | uat | prd."
  type        = string

  validation {
    condition     = contains(["dev", "tst", "uat", "prd", "sb3"], var.environment)
    error_message = "environment must be one of: dev, tst, uat, prd, sb3."
  }
}

################################################################################
# Registry Configuration
################################################################################
variable "display_name" {
  description = "What the product is called. Written to one SSM parameter — not a tag."
  type        = string
}

variable "description" {
  description = "Free text, stored alongside display_name in the registry parameter."
  type        = string
  default     = ""
}

variable "owner" {
  description = "The team. Recorded in the registry parameter, not as a tag."
  type        = string
  default     = ""
}
