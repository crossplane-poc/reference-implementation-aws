################################################################################
# Identity
################################################################################
variable "animal" {
  description = "The product's UID. Second segment of every name this module creates."
  type        = string
}

variable "component" {
  description = "What this workload is — \"be\", \"fe\", \"worker\". The XR's own name."
  type        = string
}

variable "environment" {
  description = "dev | tst | uat | prd. Always the last segment of a name, and names the cluster."
  type        = string

  validation {
    condition     = contains(["dev", "tst", "uat", "prd", "sb3"], var.environment)
    error_message = "environment must be one of: dev, tst, uat, prd, sb3."
  }
}

################################################################################
# Network Policies
################################################################################
variable "container_port" {
  description = "The port the pods listen on. What the load balancer is allowed to reach."
  type        = number
  default     = 8000
}

variable "database" {
  description = "Name of the Database this workload uses, or empty. Opens egress to the database subnets and pulls in its connection details."
  type        = string
  default     = ""
}

variable "ingress_enabled" {
  description = "Whether a load balancer fronts this workload, which opens ingress from the private subnets."
  type        = bool
  default     = false
}

variable "buckets" {
  description = "Names of the ObjectStores this workload uses. Opens egress to the S3 VPC endpoint and pulls in their connection details."
  type        = list(string)
  default     = []
}

variable "bedrock" {
  description = "Whether this workload calls Bedrock, which grants model invocation and opens egress to the bedrock-runtime VPC endpoint."
  type        = bool
  default     = false
}

################################################################################
# Model Approval
################################################################################
variable "bedrock_inference_profiles" {
  description = "Platform-approved EU system inference profile IDs."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for id in var.bedrock_inference_profiles : startswith(id, "eu.") && !strcontains(id, "*")])
    error_message = "Only explicit EU inference profile IDs are accepted."
  }
}
