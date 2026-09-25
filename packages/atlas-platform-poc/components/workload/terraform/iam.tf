################################################################################
# The workload's own identity (IRSA)
#
# Created empty. Every permission this role ends up with is attached by whatever granted it:
# a Database's IAM-auth policy, an ObjectStore's read or write policy. That is why the name is
# a contract — those modules build it from the service name without looking the role up.
################################################################################
data "aws_iam_policy_document" "service_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = [local.service_account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service" {
  name               = local.service_role_name
  description        = "Runtime identity for ${var.component} in ${var.animal}"
  assume_role_policy = data.aws_iam_policy_document.service_assume_role.json

  tags = merge(local.tags, { Name = local.service_role_name })
}
