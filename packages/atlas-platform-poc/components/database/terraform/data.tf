################################################################################
# AWS Account & Region
################################################################################
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

################################################################################
# EKS Cluster
#
# The cluster is the one thing an environment is named after, and it knows its own VPC and the
# security group its nodes carry — which is what the database has to let in.
#
# sb3 PoC only: this account has exactly one EKS cluster, and it predates ADP's own
# atlas-<env>-<region> naming convention, so it's discovered rather than named.
################################################################################
data "aws_eks_clusters" "available" {}

data "aws_eks_cluster" "main" {
  name = one(data.aws_eks_clusters.available.names)
}

data "aws_vpc" "main" {
  id = data.aws_eks_cluster.main.vpc_config[0].vpc_id
}

################################################################################
# Database Subnets
################################################################################
data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "database"
  }
}

################################################################################
# Database Availability Zones
################################################################################
data "aws_subnet" "database" {
  for_each = toset(data.aws_subnets.database.ids)
  id       = each.value
}
