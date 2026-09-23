locals {
  # The authoritative animal -> display-name mapping; cost tooling joins to this.
  registry_path = "/atlas/${var.environment}/products/${var.animal}"

  namespace = var.animal

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
