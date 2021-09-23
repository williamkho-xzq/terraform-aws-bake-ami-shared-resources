data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_ip_ranges" "current_region_codebuild" {
  regions  = [data.aws_region.current.name]
  services = ["codebuild"]
}

data "aws_subnet_ids" "main" {
  vpc_id = data.aws_vpc.selected.id

  tags = {
    Tier = var.subnet_tier
  }
}

resource "random_shuffle" "subnet_id" {
  input        = data.aws_subnet_ids.main.ids
  result_count = 1
}

data "aws_subnet" "selected" {
  id = random_shuffle.subnet_id.result[0]
}

## Will be required if the codebuild is in the VPC
# data "aws_iam_policy_document" "codebuild_ec2" {
#   statement {
#     effect = "Allow"
#
#     actions = [
#       "ec2:CreateNetworkInterface",
#       "ec2:DescribeDhcpOptions",
#       "ec2:DescribeNetworkInterfaces",
#       "ec2:DeleteNetworkInterface",
#       "ec2:DescribeSubnets",
#       "ec2:DescribeSecurityGroups",
#       "ec2:DescribeVpcs",
#     ]
#
#     resources = [
#       "*",
#     ]
#   }
#
#   statement {
#     effect = "Allow"
#
#     actions = [
#       "ec2:CreateNetworkInterfacePermission",
#     ]
#
#     resources = [
#       "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*",
#     ]
#
#     condition {
#       test     = "StringEquals"
#       variable = "ec2:AuthorizedService"
#
#       values = [
#         "codebuild.amazonaws.com",
#       ]
#     }
#
#     condition {
#       test     = "StringEquals"
#       variable = "ec2:Subnet"
#
#       values = [
#         "${data.aws_subnet.selected.arn}",
#       ]
#     }
#   }
# }

data "aws_iam_policy_document" "codebuild_s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.codebuild_cache.arn}/*",
      "${aws_s3_bucket.codepipeline_artifact.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.codebuild_cache.arn}/*",
      "${aws_s3_bucket.codepipeline_artifact.arn}/*",
      "${aws_s3_bucket.application_binary.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "codebuild_cloudwatch" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.product_domain}*:*",
    ]
  }
}

data "aws_iam_policy_document" "codebuild_packer" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key-pair/packer_*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:launch-template/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:placement-group/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/${aws_security_group.template.id}",
      "arn:aws:ec2:${data.aws_region.current.name}::snapshot/*",
      data.aws_subnet.selected.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"

      values = [
        "management",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ProductDomain"

      values = [
        var.product_domain,
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}::image/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:Owner"
      values   = var.base_ami_owners
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:InstanceProfile"

      values = [
        module.template_instance_role.instance_profile_name,
        module.template_instance_role.instance_profile_arn,
        module.template_instance_role.instance_profile_unique_id,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Name"

      values = [
        "${var.product_domain}-packer",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/Service"

      values = [
        "${var.product_domain}*",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ProductDomain"

      values = [
        var.product_domain,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"

      values = [
        "management",
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:StopInstances",
      "ec2:TerminateInstances",
    ]

    resources = [
      "*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:InstanceProfile"

      values = [
        module.template_instance_role.instance_profile_name,
        module.template_instance_role.instance_profile_arn,
        module.template_instance_role.instance_profile_unique_id,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Name"

      values = [
        "${var.product_domain}-packer",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Service"

      values = [
        "${var.product_domain}*",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/ProductDomain"

      values = [
        var.product_domain,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"

      values = [
        "management",
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole",
    ]

    resources = [
      module.template_instance_role.role_arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:GetInstanceProfile"
    ]

    resources = [
      module.template_instance_role.instance_profile_arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CopyImage",
      "ec2:CreateImage",
      "ec2:DeregisterImage",
      "ec2:ModifyImageAttribute",
      "ec2:RegisterImage",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:ModifySnapshotAttribute",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateKeypair",
      "ec2:DeleteKeypair",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:ModifyInstanceAttribute",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/*",
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"

      values = [
        "CreateVolume",
        "RunInstances",
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}::image/*",
      "arn:aws:ec2:${data.aws_region.current.name}::snapshot/*",
    ]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/Service"

      values = [
        "${var.product_domain}*",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ServiceVersion"

      values = [
        "*",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ProductDomain"

      values = [
        var.product_domain,
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/BaseAmiId"

      values = [
        "*",
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
    ]

    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "codepipeline_s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.codepipeline_artifact.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetBucketVersioning",
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]

    resources = [
      "arn:aws:s3:::${var.product_domain}-appbin-${data.aws_caller_identity.current.account_id}-*",
      "arn:aws:s3:::${var.product_domain}-appbin-${data.aws_caller_identity.current.account_id}-*/*",
    ]
  }
}

data "aws_iam_policy_document" "appbin_bucket_policy" {
  statement {
    sid    = "AppbinWrite"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = var.appbin_writers
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.application_binary.name}/${var.product_domain}*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control",
      ]
    }
  }

  statement {
    sid    = "DenyAllUnEncryptedHTTPAccess"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${module.application_binary.name}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        "false",
      ]
    }
  }

  statement {
    sid    = "DenyIncorrectEncryptionHeader"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.application_binary.name}/*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        "AES256",
      ]
    }
  }

  statement {
    sid    = "DenyUnEncryptedObjectUploads"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.application_binary.name}/*",
    ]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        "true",
      ]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_logs_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      "arn:aws:s3:::${module.cloudtrail_logs.name}",
    ]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.cloudtrail_logs.name}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control",
      ]
    }
  }
}

data "aws_iam_policy_document" "codebuild_cache_bucket_policy" {
  statement {
    sid    = "DenyAllUnEncryptedHTTPAccess"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${module.codebuild_cache.name}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        "false",
      ]
    }
  }

  statement {
    sid    = "DenyIncorrectEncryptionHeader"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.codebuild_cache.name}/*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        "aws:kms",
        "AES256",
      ]
    }
  }

  statement {
    sid    = "DenyUnEncryptedObjectUploads"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.codebuild_cache.name}/*",
    ]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        "true",
      ]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_artifact_bucket_policy" {
  statement {
    sid    = "DenyAllUnEncryptedHTTPAccess"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${module.codepipeline_artifact_bucket_name.name}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        "false",
      ]
    }
  }

  statement {
    sid    = "DenyIncorrectEncryptionHeader"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.codepipeline_artifact_bucket_name.name}/*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        "aws:kms",
        "AES256",
      ]
    }
  }

  statement {
    sid    = "DenyUnEncryptedObjectUploads"
    effect = "Deny"

    principals {
      type = "*"

      identifiers = [
        "*",
      ]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.codepipeline_artifact_bucket_name.name}/*",
    ]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"

      values = [
        "true",
      ]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_codebuild" {
  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = [
      "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${var.product_domain}*",
    ]
  }
}

data "aws_iam_policy_document" "codepipeline_lambda" {
  statement {
    effect = "Allow"

    actions = [
      "lambda:ListFunctions",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction",
    ]

    resources = [
      var.lambda_function_arn,
    ]
  }
}

data "aws_iam_policy_document" "events_codepipeline" {
  statement {
    effect = "Allow"

    actions = [
      "codepipeline:StartPipelineExecution",
    ]

    resources = [
      "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.product_domain}*",
    ]
  }
}
