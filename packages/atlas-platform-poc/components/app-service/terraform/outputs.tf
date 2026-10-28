output "role_arn" {
  value = aws_iam_role.service.arn
}

output "configuration_revision" {
  value = local.connections_ready ? sha256(jsonencode({ for name, cm in kubernetes_config_map_v1.consumed : name => cm.data })) : ""
}
