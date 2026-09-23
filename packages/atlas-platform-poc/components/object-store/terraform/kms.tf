data "aws_iam_session_context" "provisioner" {
  arn = data.aws_caller_identity.current.arn
}

module "kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "= 4.2.0"

  description             = "Encrypts s3://${local.name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  enable_default_policy   = true

  key_administrators = [data.aws_iam_session_context.provisioner.issuer_arn]

  key_users = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/IAGAdmin"]

  # computed_aliases, not aliases: the alias name isn't known until plan time.
  computed_aliases = {
    bucket = { name = local.name }
  }

  tags = merge(local.tags, { Name = local.name })
}
