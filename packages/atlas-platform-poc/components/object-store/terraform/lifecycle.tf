locals {
  # abort_incomplete_multipart_upload applies even with no expiry set.
  lifecycle_rule = merge(
    {
      id                                     = "lifecycle"
      enabled                                = true
      abort_incomplete_multipart_upload_days = 7
    },
    var.retention_days > 0 ? {
      expiration                    = { days = var.retention_days }
      noncurrent_version_expiration = { noncurrent_days = var.retention_days }
    } : {}
  )
}
