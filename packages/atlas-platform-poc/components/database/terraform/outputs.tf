output "database_host" {
  value = module.aurora.cluster_endpoint
}

output "database_reader_host" {
  value = module.aurora.cluster_reader_endpoint
}

output "database_port" {
  value = tostring(module.aurora.cluster_port)
}

output "database_name" {
  value = module.aurora.cluster_database_name
}

output "cluster_identifier" {
  value = module.aurora.cluster_id
}
