################################################################################
# Bedrock Inference Profiles
################################################################################
data "aws_bedrock_inference_profile" "approved" {
  for_each             = var.bedrock ? toset(var.bedrock_inference_profiles) : toset([])
  inference_profile_id = each.value
}

data "aws_iam_policy_document" "bedrock" {
  statement {
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [for profile in data.aws_bedrock_inference_profile.approved : profile.inference_profile_arn]
  }
  statement {
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = flatten([for profile in data.aws_bedrock_inference_profile.approved : [for model in profile.models : model.model_arn]])
    condition {
      test     = "ArnEquals"
      variable = "bedrock:InferenceProfileArn"
      values   = [for profile in data.aws_bedrock_inference_profile.approved : profile.inference_profile_arn]
    }
  }
}

resource "aws_iam_policy" "bedrock" {
  count  = var.bedrock ? 1 : 0
  name   = "${local.name}-bedrock"
  policy = data.aws_iam_policy_document.bedrock.json
  tags   = local.tags
  lifecycle {
    precondition {
      condition     = length(var.bedrock_inference_profiles) > 0
      error_message = "Bedrock requires a platform-approved EU inference profile."
    }
  }
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  count      = var.bedrock ? 1 : 0
  role       = aws_iam_role.service.name
  policy_arn = aws_iam_policy.bedrock[0].arn
}
