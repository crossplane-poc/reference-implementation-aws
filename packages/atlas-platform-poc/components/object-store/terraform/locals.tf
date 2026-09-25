locals {
  name = "adp-${var.animal}-${var.component}-${var.environment}"

  grants = { for a in var.access : a.service => {
    level = a.level
    role  = "adp-${var.animal}-${a.service}-${var.environment}"
  } }

  object_actions = {
    ro = ["s3:GetObject", "s3:GetObjectTagging"]
    rw = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
      "s3:DeleteObjectTagging",
    ]
  }

  # group:product is the UID, not the display name, so cost history survives a rename.
  tags = {
    "group:op-co-code"     = "iaggbs"
    "group:platform"       = "atlas"
    "group:product-family" = "atlas"
    "group:environment"    = var.environment
    "group:product"        = var.animal
    "atlas:uid"            = var.animal
    "env"                  = var.environment
    "ManagedBy"            = "crossplane"
  }
}
