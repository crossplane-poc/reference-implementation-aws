# Separate from admin: a service must never be able to reach admin_iam.
data "aws_iam_policy_document" "connect" {
  statement {
    sid     = "ConnectAsApplicationUsers"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "${local.db_user_arn_prefix}/iam_user",
    ]
  }
}

data "aws_iam_policy_document" "admin" {
  statement {
    sid       = "ConnectAsAdmin"
    effect    = "Allow"
    actions   = ["rds-db:connect"]
    resources = ["${local.db_user_arn_prefix}/admin_iam"]
  }
}

resource "aws_iam_policy" "connect" {
  name        = "${local.name}-connect"
  description = "Connect to ${local.name} as iam_user"
  policy      = data.aws_iam_policy_document.connect.json

  tags = merge(local.tags, { Name = "${local.name}-connect" })
}

resource "aws_iam_policy" "admin" {
  name        = "${local.name}-admin"
  description = "Connect to ${local.name} as admin_iam"
  policy      = data.aws_iam_policy_document.admin.json

  tags = merge(local.tags, { Name = "${local.name}-admin" })
}

resource "aws_iam_role_policy_attachment" "connect" {
  for_each = toset(local.auth_roles)

  role       = each.value
  policy_arn = aws_iam_policy.connect.arn
}

resource "aws_iam_role_policy_attachment" "admin" {
  for_each = toset(local.admin_roles)

  role       = each.value
  policy_arn = aws_iam_policy.admin.arn
}
