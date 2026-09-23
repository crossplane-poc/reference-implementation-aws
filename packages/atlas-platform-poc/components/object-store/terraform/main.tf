data "aws_caller_identity" "current" {}

module "bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "= 5.16.0"

  bucket = local.name

  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"
  attach_deny_insecure_transport_policy = true
  allowed_kms_key_arn                   = module.kms_key.key_arn

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.kms_key.key_arn
      }
      bucket_key_enabled = true
      # Required for idempotency with aws provider 6.28.
      blocked_encryption_types = ["NONE"]
    }
  }

  lifecycle_rule = [local.lifecycle_rule]

  tags = merge(local.tags, { Name = local.name })
}
