resource "aws_kms_key" "rds" {
  description             = "Encrypts the ${local.name} Aurora cluster"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key.json

  tags = merge(local.tags, { Name = local.name })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.rds.key_id
}

# Separate statement from the account-root one so key admin policy can change without replacing the key.
data "aws_iam_session_context" "provisioner" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "key" {
  statement {
    sid       = "Provisioner"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_session_context.provisioner.issuer_arn]
    }
  }

  statement {
    sid       = "AccountRoot"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "KeyAdmins"
    effect    = "Allow"
    actions   = ["kms:Describe*", "kms:Get*", "kms:List*", "kms:Decrypt"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/IAGAdmin"]
    }
  }
}

removed {
  from = aws_kms_key_policy.rds
  lifecycle {
    destroy = false
  }
}
