resource "aws_ssm_parameter" "registry" {
  name        = local.registry_path
  description = "Atlas product registry entry for ${var.animal}"
  type        = "String"

  value = jsonencode({
    uid         = var.animal
    name        = var.display_name
    description = var.description
    owner       = var.owner
    namespace   = local.namespace
    environment = var.environment
  })

  tags = merge(local.tags, { Name = local.registry_path })
}
