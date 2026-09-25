locals {
  name = "adp-${var.animal}-${var.component}-${var.environment}"

  # A workload has a namespace to itself; the product's own namespace is where the things with
  # no pods live, and where the ConfigMaps this one consumes are published.
  namespace = "${var.animal}-${var.component}"

  # The name Database and ObjectStore attach their access policies to. It is derived there from
  # the service name alone, so this string is a contract, not a choice.
  service_role_name = local.name

  account_id         = data.aws_caller_identity.current.account_id
  oidc_provider_host = replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn  = "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_provider_host}"
  service_account_id = "system:serviceaccount:${local.namespace}:${var.component}"

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

  pod_labels = {
    "app"                  = var.component
    "atlas.iag.ai/product" = var.animal
  }

  uses_database = var.database != ""
  uses_buckets  = length(var.buckets) > 0

  database_subnet_cidrs = [for s in data.aws_subnet.database : s.cidr_block]
  private_subnet_cidrs  = [for s in data.aws_subnet.private : s.cidr_block]
  sts_endpoint_ips      = [for n in data.aws_network_interface.sts_endpoint : n.private_ip]
  s3_endpoint_ips       = [for n in data.aws_network_interface.s3_endpoint : n.private_ip]
  bedrock_endpoint_ips  = [for n in data.aws_network_interface.bedrock_runtime_endpoint : n.private_ip]

  consumed_configmaps = toset(concat(
    ["product-connection"],
    local.uses_database ? ["${var.database}-connection"] : [],
    [for bucket in var.buckets : "${bucket}-connection"],
  ))
  connection_requirements = merge(
    { "product-connection" = ["PRODUCT_UID", "PRODUCT_NAME", "PRODUCT_ENVIRONMENT", "PRODUCT_REGISTRY_PARAMETER"] },
    local.uses_database ? { "${var.database}-connection" = ["DATABASE_HOST", "DATABASE_PORT", "DATABASE_NAME", "DATABASE_USER"] } : {},
    { for bucket in var.buckets : "${bucket}-connection" => ["S3_BUCKET", "S3_BUCKET_ARN"] },
  )
  available_connections = {
    for cm in data.kubernetes_resources.connections.objects : cm.metadata.name => try(cm.data, {})
    if contains(local.consumed_configmaps, cm.metadata.name) && alltrue([
      for key in lookup(local.connection_requirements, cm.metadata.name, []) : try(cm.data[key] != "", false)
    ])
  }
  connections_ready = length(local.available_connections) == length(local.consumed_configmaps)
}
