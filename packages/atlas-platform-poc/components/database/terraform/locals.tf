# Naming: adp-<animal>-<component>-<environment>. No region in the identifier — environment
# is the discriminator, region is a property of the account.
locals {
  name = "adp-${var.animal}-${var.component}-${var.environment}"

  # Postgres identifiers reject hyphens, and a UID is <adjective>-<animal>.
  database_name = "${replace(var.animal, "-", "")}db"

  # RDS rejects a family/engine-version mismatch at create time without naming either, so this
  # is derived rather than a separate variable.
  parameter_group_family = "aurora-postgresql${split(".", var.engine_version)[0]}"

  capacity = {
    small  = { min = 0.5, max = 2, instances = 1 }
    medium = { min = 1, max = 8, instances = 1 }
    large  = { min = 2, max = 16, instances = 2 }
  }[var.size]

  database_azs             = sort(distinct([for subnet in data.aws_subnet.database : subnet.availability_zone]))
  instance_count           = var.environment == "prd" ? max(2, local.capacity.instances) : local.capacity.instances
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/atlas-component-boundary"

  is_production          = var.environment == "prd"
  backup_retention_days  = local.is_production ? 30 : 7
  deletion_protection    = local.is_production
  cloudwatch_log_exports = ["postgresql"]

  vpc_id                 = data.aws_vpc.main.id
  vpc_cidr               = data.aws_vpc.main.cidr_block
  database_subnet_ids    = data.aws_subnets.database.ids
  node_security_group_id = data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

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

  auth_roles  = [for s in var.access : "adp-${var.animal}-${s}-${var.environment}"]
  admin_roles = var.admin_access

  db_user_arn_prefix = "arn:aws:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.aurora.cluster_resource_id}"
}
