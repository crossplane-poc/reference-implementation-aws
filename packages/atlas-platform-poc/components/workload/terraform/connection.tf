################################################################################
# Connection ConfigMaps
################################################################################
data "kubernetes_resources" "connections" {
  api_version = "v1"
  kind        = "ConfigMap"
  namespace   = var.animal
}

resource "kubernetes_config_map_v1" "consumed" {
  for_each = local.available_connections

  metadata {
    name      = each.key
    namespace = local.namespace
    labels    = local.pod_labels
  }
  data = each.value
}
