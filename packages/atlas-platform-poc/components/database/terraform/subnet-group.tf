resource "aws_db_subnet_group" "this" {
  name        = local.name
  description = "Subnets for the ${local.name} Aurora cluster"
  subnet_ids  = local.database_subnet_ids

  lifecycle {
    precondition {
      condition     = length(local.database_azs) >= 2
      error_message = "Database subnets must span at least two availability zones."
    }
  }

  tags = merge(local.tags, { Name = local.name })
}
