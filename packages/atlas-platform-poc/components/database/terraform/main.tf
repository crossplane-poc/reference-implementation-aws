module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "= 10.4.0"

  name = local.name

  engine         = "aurora-postgresql"
  engine_version = var.engine_version

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  serverlessv2_scaling_configuration = {
    min_capacity = local.capacity.min
    max_capacity = local.capacity.max
  }

  instances = {
    for i in range(local.instance_count) : i + 1 => {
      availability_zone                     = local.database_azs[i % length(local.database_azs)]
      instance_class                        = "db.serverless"
      publicly_accessible                   = false
      auto_minor_version_upgrade            = true
      monitoring_interval                   = 30
      performance_insights_enabled          = true
      performance_insights_retention_period = 7
    }
  }

  database_name   = local.database_name
  master_username = "postgres"

  # Applications authenticate as iam_user with a 15-minute IAM token, not a password.
  iam_database_authentication_enabled = true
  manage_master_user_password         = true

  vpc_id                 = local.vpc_id
  db_subnet_group_name   = aws_db_subnet_group.this.name
  create_db_subnet_group = false
  create_security_group  = false
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period   = local.backup_retention_days
  preferred_backup_window   = "02:00-03:00"
  skip_final_snapshot       = !local.deletion_protection
  final_snapshot_identifier = local.deletion_protection ? "${local.name}-final" : null
  deletion_protection       = local.deletion_protection

  enabled_cloudwatch_logs_exports = local.cloudwatch_log_exports
  create_cloudwatch_log_group     = true
  create_monitoring_role          = true
  iam_role_permissions_boundary   = local.permissions_boundary_arn

  # use_name_prefix defaults to true, which would append a random suffix.
  cluster_parameter_group = {
    name            = local.name
    use_name_prefix = false
    family          = local.parameter_group_family
    parameters = [
      # Without this, a client that omits sslmode connects in the clear.
      { name = "rds.force_ssl", value = "1", apply_method = "immediate" },
    ]
  }

  db_parameter_group = {
    name            = "${local.name}-instance"
    use_name_prefix = false
    family          = local.parameter_group_family
  }

  tags = local.tags
}
