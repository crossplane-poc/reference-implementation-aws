resource "aws_iam_policy" "access" {
  for_each = local.grants

  name        = "${local.name}-${each.value.level}-${each.key}"
  description = "${each.value.level} access to s3://${local.name} for ${each.key}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [module.bucket.s3_bucket_arn]
      },
      {
        Sid      = "ObjectActions"
        Effect   = "Allow"
        Action   = local.object_actions[each.value.level]
        Resource = ["${module.bucket.s3_bucket_arn}/*"]
      },
      {
        # Without this, GetObject fails with AccessDenied and no mention of KMS.
        Sid      = "UseTheBucketKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [module.kms_key.key_arn]
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "access" {
  for_each = local.grants

  role       = each.value.role
  policy_arn = aws_iam_policy.access[each.key].arn
}
