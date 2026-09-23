resource "aws_security_group" "rds" {
  name        = "${local.name}-rds"
  description = "Ingress to the ${local.name} Aurora cluster"
  vpc_id      = local.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-rds" })
}

resource "aws_vpc_security_group_ingress_rule" "from_eks_nodes" {
  security_group_id = aws_security_group.rds.id

  description                  = "EKS nodes reach the database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = local.node_security_group_id
}
