################################################################################
# The network rules that name an AWS address
#
# A policy that names a pod is rendered by the composition. The ones here name subnets and
# endpoint addresses, which only the account can answer for, so they are built alongside the
# data.tf lookups that feed them.
################################################################################
resource "kubernetes_network_policy_v1" "allow_aws" {
  lifecycle {
    precondition {
      condition     = length(local.sts_endpoint_ips) > 0
      error_message = "Network discovery returned no peers for allow_aws."
    }
  }

  metadata {
    name      = "${var.component}-allow-aws"
    namespace = local.namespace
    labels    = local.pod_labels
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      # Without STS the IRSA token cannot be exchanged and every AWS call fails.
      dynamic "to" {
        for_each = local.sts_endpoint_ips

        content {
          ip_block {
            cidr = "${to.value}/32"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_database" {
  lifecycle {
    precondition {
      condition     = length(local.database_subnet_cidrs) > 0
      error_message = "Network discovery returned no peers for allow_database."
    }
  }

  count = local.uses_database ? 1 : 0

  metadata {
    name      = "${var.component}-allow-database"
    namespace = local.namespace
    labels    = local.pod_labels
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      dynamic "to" {
        for_each = local.database_subnet_cidrs

        content {
          ip_block {
            cidr = to.value
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_from_alb" {
  lifecycle {
    precondition {
      condition     = length(local.private_subnet_cidrs) > 0
      error_message = "Network discovery returned no peers for allow_from_alb."
    }
  }

  count = var.ingress_enabled ? 1 : 0

  metadata {
    name      = "${var.component}-allow-from-alb"
    namespace = local.namespace
    labels    = local.pod_labels
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress"]

    ingress {
      # The load balancer's nodes sit in the private subnets and target pods directly, so the
      # rule is the subnet, not the balancer.
      dynamic "from" {
        for_each = local.private_subnet_cidrs

        content {
          ip_block {
            cidr = from.value
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = tostring(var.container_port)
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_s3" {
  lifecycle {
    precondition {
      condition     = length(local.s3_endpoint_ips) > 0
      error_message = "Network discovery returned no peers for allow_s3."
    }
  }

  count = local.uses_buckets ? 1 : 0

  metadata {
    name      = "${var.component}-allow-s3"
    namespace = local.namespace
    labels    = local.pod_labels
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      dynamic "to" {
        for_each = local.s3_endpoint_ips

        content {
          ip_block {
            cidr = "${to.value}/32"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "allow_bedrock" {
  lifecycle {
    precondition {
      condition     = length(local.bedrock_endpoint_ips) > 0
      error_message = "Network discovery returned no peers for allow_bedrock."
    }
  }

  count = var.bedrock ? 1 : 0

  metadata {
    name      = "${var.component}-allow-bedrock"
    namespace = local.namespace
    labels    = local.pod_labels
  }

  spec {
    pod_selector {}

    policy_types = ["Egress"]

    egress {
      dynamic "to" {
        for_each = local.bedrock_endpoint_ips

        content {
          ip_block {
            cidr = "${to.value}/32"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}
