# A VPC-attached Lambda connects once with the master secret and creates iam_user,
# iam_migration_user and admin_iam, plus the vector/pg_trgm extensions. Idempotent.
resource "aws_security_group" "bootstrap" {
  name        = "${local.name}-bootstrap"
  description = "The ${local.name} bootstrap Lambda"
  vpc_id      = local.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-bootstrap" })
}

resource "aws_vpc_security_group_egress_rule" "bootstrap_to_rds" {
  security_group_id = aws_security_group.bootstrap.id

  description                  = "Reach the database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_egress_rule" "bootstrap_to_endpoints" {
  security_group_id = aws_security_group.bootstrap.id

  # Scoped to the VPC (the Secrets Manager interface endpoint), not the internet.
  description = "Reach Secrets Manager through the VPC endpoint"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = local.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_bootstrap" {
  security_group_id = aws_security_group.rds.id

  description                  = "The bootstrap Lambda reaches the database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.bootstrap.id
}

module "bootstrap" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "= 8.8.0"

  function_name = "${local.name}-bootstrap"
  description   = "Creates the IAM-auth database roles on ${local.name}"

  package_type   = "Image"
  image_uri      = var.bootstrap_image
  create_package = false
  timeout        = 60

  vpc_subnet_ids         = local.database_subnet_ids
  vpc_security_group_ids = [aws_security_group.bootstrap.id]
  attach_network_policy  = true

  attach_policy_statements = true
  policy_statements = {
    read_master_secret = {
      sid       = "ReadMasterSecret"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [module.aurora.cluster_master_user_secret[0].secret_arn]
    }
  }

  environment_variables = {
    DB_ENDPOINT       = module.aurora.cluster_endpoint
    DB_PORT           = tostring(module.aurora.cluster_port)
    DB_NAME           = module.aurora.cluster_database_name
    MASTER_SECRET_ARN = module.aurora.cluster_master_user_secret[0].secret_arn
  }

  cloudwatch_logs_retention_in_days = 14
  role_permissions_boundary         = local.permissions_boundary_arn
  role_name                         = "${local.name}-bootstrap"

  tags = local.tags

  depends_on = [
    module.aurora,
    aws_vpc_security_group_ingress_rule.rds_from_bootstrap,
  ]
}

# `image` in the input forces re-invocation whenever it changes; the handler ignores unknown keys.
resource "aws_lambda_invocation" "bootstrap" {
  function_name = module.bootstrap.lambda_function_name

  input = jsonencode({
    action = "bootstrap"
    image  = var.bootstrap_image
  })

  depends_on = [
    module.bootstrap,
    aws_vpc_security_group_egress_rule.bootstrap_to_rds,
    aws_vpc_security_group_egress_rule.bootstrap_to_endpoints,
  ]
}
