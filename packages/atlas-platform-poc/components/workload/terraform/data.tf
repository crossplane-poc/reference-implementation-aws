################################################################################
# AWS Account & Region
################################################################################
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

################################################################################
# EKS Cluster
#
# Everything below hangs off the cluster rather than off a tag filter: the cluster is the one
# thing an environment is named after, and it knows its own VPC, node security group and OIDC
# issuer.
#
# sb3 PoC only: this account has exactly one EKS cluster, and it predates ADP's own
# atlas-<env>-<region> naming convention, so it's discovered rather than named.
################################################################################
data "aws_eks_clusters" "available" {}

data "aws_eks_cluster" "main" {
  name = one(data.aws_eks_clusters.available.names)
}

################################################################################
# Subnets
################################################################################
data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.main.vpc_config[0].vpc_id]
  }

  tags = {
    Type = "database"
  }
}

data "aws_subnet" "database" {
  for_each = toset(data.aws_subnets.database.ids)
  id       = each.value
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.main.vpc_config[0].vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

################################################################################
# STS VPC Endpoint
#
# A pod's egress rules name the endpoint's own addresses, so the ENIs are what matter here —
# the endpoint id itself is never used.
################################################################################
data "aws_vpc_endpoint" "sts" {
  vpc_id       = data.aws_eks_cluster.main.vpc_config[0].vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.sts"
  state        = "available"
}

data "aws_network_interfaces" "sts_endpoint" {
  filter {
    name   = "interface-type"
    values = ["vpc_endpoint"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.main.vpc_config[0].vpc_id]
  }

  filter {
    name   = "description"
    values = ["VPC Endpoint Interface ${data.aws_vpc_endpoint.sts.id}"]
  }
}

data "aws_network_interface" "sts_endpoint" {
  for_each = toset(data.aws_network_interfaces.sts_endpoint.ids)
  id       = each.value
}

################################################################################
# S3 VPC Endpoint
#
# An interface endpoint with private DNS, so every S3 call from a pod is answered by these
# ENIs and a pod that may reach no AWS address reaches no bucket either.
################################################################################
data "aws_vpc_endpoint" "s3" {
  count = local.uses_buckets ? 1 : 0

  vpc_id       = data.aws_eks_cluster.main.vpc_config[0].vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.s3"
  state        = "available"

  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
}

data "aws_network_interfaces" "s3_endpoint" {
  count = local.uses_buckets ? 1 : 0

  filter {
    name   = "interface-type"
    values = ["vpc_endpoint"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.main.vpc_config[0].vpc_id]
  }

  filter {
    name   = "description"
    values = ["VPC Endpoint Interface ${data.aws_vpc_endpoint.s3[0].id}"]
  }
}

data "aws_network_interface" "s3_endpoint" {
  for_each = local.uses_buckets ? toset(data.aws_network_interfaces.s3_endpoint[0].ids) : toset([])
  id       = each.value
}

################################################################################
# Bedrock Runtime VPC Endpoint
################################################################################
data "aws_vpc_endpoint" "bedrock_runtime" {
  count = var.bedrock ? 1 : 0

  vpc_id       = data.aws_eks_cluster.main.vpc_config[0].vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.bedrock-runtime"
  state        = "available"
}

data "aws_network_interfaces" "bedrock_runtime_endpoint" {
  count = var.bedrock ? 1 : 0

  filter {
    name   = "interface-type"
    values = ["vpc_endpoint"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_eks_cluster.main.vpc_config[0].vpc_id]
  }

  filter {
    name   = "description"
    values = ["VPC Endpoint Interface ${data.aws_vpc_endpoint.bedrock_runtime[0].id}"]
  }
}

data "aws_network_interface" "bedrock_runtime_endpoint" {
  for_each = var.bedrock ? toset(data.aws_network_interfaces.bedrock_runtime_endpoint[0].ids) : toset([])
  id       = each.value
}
