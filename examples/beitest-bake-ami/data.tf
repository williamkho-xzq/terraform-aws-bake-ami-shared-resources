data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "lambda_share_ami" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${module.lambda_function_name.name}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${module.lambda_function_name.name}:*",
    ]
  }

  statement = {
    effect = "Allow"

    actions = [
      "ec2:ModifyImageAttribute",
    ]

    resources = [
      "*",
    ]
  }

  statement = {
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
    ]

    resources = [
      "${aws_ssm_parameter.target_accounts.arn}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${module.bei.codepipeline_artifact_bucket}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutJobFailureResult",
    ]

    resources = [
      "*",
    ]
  }
}

data "archive_file" "share_ami_function" {
  type        = "zip"
  source_file = "${path.module}/main.py"
  output_path = "${path.module}/.terraform/generated/function.zip"
}
