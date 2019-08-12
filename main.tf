module "codebuild_role" {
  source = "github.com/traveloka/terraform-aws-iam-role.git//modules/service?ref=v1.0.2"

  role_identifier            = "${var.product_domain}-bake-ami"
  role_description           = "Service Role for CodeBuild Bake AMI"
  role_force_detach_policies = "true"
  role_max_session_duration  = "43200"
  product_domain             = "${var.product_domain}"
  environment                = "management"

  aws_service = "codebuild.amazonaws.com"
}

resource "aws_iam_role_policy" "codebuild-policy-packer" {
  name   = "CodeBuildBakeAmi-${data.aws_region.current.name}-${var.product_domain}-packer"
  role   = "${module.codebuild_role.role_name}"
  policy = "${data.aws_iam_policy_document.codebuild_packer.json}"
}

resource "aws_iam_role_policy" "codebuild_policy_cloudwatch" {
  name   = "CodeBuildBakeAmi-${data.aws_region.current.name}-${var.product_domain}-cloudwatch"
  role   = "${module.codebuild_role.role_name}"
  policy = "${data.aws_iam_policy_document.codebuild_cloudwatch.json}"
}

resource "aws_iam_role_policy" "codebuild_policy_s3" {
  name   = "CodeBuildBakeAmi-${data.aws_region.current.name}-${var.product_domain}-S3"
  role   = "${module.codebuild_role.role_name}"
  policy = "${data.aws_iam_policy_document.codebuild_s3.json}"
}

module "codepipeline_role" {
  source = "github.com/traveloka/terraform-aws-iam-role.git//modules/service?ref=v1.0.2"

  role_identifier            = "${var.product_domain}-ami-baking"
  role_description           = "Service Role for CodePipeline Bake AMI"
  role_force_detach_policies = "true"
  role_max_session_duration  = "43200"
  product_domain             = "${var.product_domain}"
  environment                = "management"

  aws_service = "codepipeline.amazonaws.com"
}

resource "aws_iam_role_policy" "codepipeline_s3" {
  name   = "CodePipelineBakeAmi-${data.aws_region.current.name}-${var.product_domain}-S3"
  role   = "${module.codepipeline_role.role_name}"
  policy = "${data.aws_iam_policy_document.codepipeline_s3.json}"
}

resource "aws_iam_role_policy" "codepipeline_codebuild" {
  name   = "CodePipelineBakeAmi-${data.aws_region.current.name}-${var.product_domain}-CodeBuild"
  role   = "${module.codepipeline_role.role_name}"
  policy = "${data.aws_iam_policy_document.codepipeline_codebuild.json}"
}

resource "aws_iam_role_policy" "codepipeline_lambda" {
  name   = "CodePipelineBakeAmi-${data.aws_region.current.name}-${var.product_domain}-Lambda"
  role   = "${module.codepipeline_role.role_name}"
  policy = "${data.aws_iam_policy_document.codepipeline_lambda.json}"
}

module "template_instance_role" {
  source = "github.com/traveloka/terraform-aws-iam-role.git//modules/instance?ref=v1.0.2"

  service_name   = "${var.product_domain}"
  product_domain = "${var.product_domain}"
  cluster_role   = "template"
  environment    = "management"
}

module "template_sg_name" {
  source = "github.com/traveloka/terraform-aws-resource-naming.git?ref=v0.17.0"

  name_prefix   = "${var.product_domain}-template"
  resource_type = "security_group"
}

resource "aws_security_group" "template" {
  name   = "${module.template_sg_name.name}"
  vpc_id = "${var.vpc_id}"

  tags {
    Name          = "${module.template_sg_name.name}"
    ProductDomain = "${var.product_domain}"
    Environment   = "management"
    Description   = "Security group for ${var.product_domain} ami baking instances"
    ManagedBy     = "Terraform"
  }
}

resource "aws_security_group_rule" "template_http_all" {
  type              = "egress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.template.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow egress to all port HTTP"
}

resource "aws_security_group_rule" "template_https_all" {
  type              = "egress"
  from_port         = "443"
  to_port           = "443"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.template.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow egress to all port HTTPS"
}

resource "aws_security_group_rule" "template_codebuild_ssh" {
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.template.id}"
  cidr_blocks       = ["${data.aws_ip_ranges.current_region_codebuild.cidr_blocks}"]
  description       = "Allow ingress from CodeBuild IP port SSH"
}

module "codepipeline_artifact_bucket_name" {
  source = "github.com/traveloka/terraform-aws-resource-naming?ref=v0.17.0"

  name_prefix   = "${var.product_domain}-codepipeline-${data.aws_caller_identity.current.account_id}-"
  resource_type = "s3_bucket"
}

resource "aws_s3_bucket" "codepipeline_artifact" {
  bucket = "${module.codepipeline_artifact_bucket_name.name}"
  acl    = "private"

  logging {
    target_bucket = "${var.logging_bucket}"
    target_prefix = "${module.codepipeline_artifact_bucket_name.name}/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  policy = "${data.aws_iam_policy_document.codepipeline_artifact_bucket_policy.json}"

  versioning {
    enabled = "true"
  }

  lifecycle_rule {
    enabled                                = "true"
    abort_incomplete_multipart_upload_days = "1"
  }

  tags {
    Name          = "${module.codepipeline_artifact_bucket_name.name}"
    ProductDomain = "${var.product_domain}"
    Description   = "CodePipeline artifact bucket for ${var.product_domain} services"
    Environment   = "management"
    ManagedBy     = "Terraform"
  }
}

module "application_binary" {
  source = "github.com/traveloka/terraform-aws-resource-naming?ref=v0.17.0"

  name_prefix   = "${var.product_domain}-appbin-${data.aws_caller_identity.current.account_id}-"
  resource_type = "s3_bucket"
}

resource "aws_s3_bucket" "application_binary" {
  bucket = "${module.application_binary.name}"
  acl    = "private"

  logging {
    target_bucket = "${var.logging_bucket}"
    target_prefix = "${module.application_binary.name}/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  policy = "${data.aws_iam_policy_document.appbin_bucket_policy.json}"

  versioning {
    enabled = "true"
  }

  lifecycle_rule {
    enabled = "true"

    expiration {
      days = "${var.appbin_expiration_days}"
    }

    noncurrent_version_expiration {
      days = "${var.appbin_expiration_days}"
    }

    transition {
      days          = "${var.appbin_standard_ia_transition_days}"
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = "${var.appbin_deep_archive_transition_days}"
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      days          = "${var.appbin_standard_ia_transition_days}"
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      days          = "${var.appbin_deep_archive_transition_days}"
      storage_class = "DEEP_ARCHIVE"
    }

    abort_incomplete_multipart_upload_days = "1"
  }

  tags {
    Name          = "${module.application_binary.name}"
    ProductDomain = "${var.product_domain}"
    Description   = "Application Binary bucket for ${var.product_domain} services"
    Environment   = "management"
    ManagedBy     = "Terraform"
  }
}

module "codebuild_cache" {
  source = "github.com/traveloka/terraform-aws-resource-naming?ref=v0.17.0"

  name_prefix   = "${var.product_domain}-codebuild-cache-${data.aws_caller_identity.current.account_id}-"
  resource_type = "s3_bucket"
}

resource "aws_s3_bucket" "codebuild_cache" {
  bucket        = "${module.codebuild_cache.name}"
  acl           = "private"
  force_destroy = "true"

  logging {
    target_bucket = "${var.logging_bucket}"
    target_prefix = "${module.codebuild_cache.name}/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  policy = "${data.aws_iam_policy_document.codebuild_cache_bucket_policy.json}"

  versioning {
    enabled = "true"
  }

  lifecycle_rule {
    enabled = "true"

    expiration {
      days = "7"
    }

    abort_incomplete_multipart_upload_days = "1"
  }

  tags {
    Name          = "${module.codebuild_cache.name}"
    ProductDomain = "${var.product_domain}"
    Description   = "CodeBuild cache bucket for ${var.product_domain} services"
    Environment   = "management"
    ManagedBy     = "Terraform"
  }
}

module "events_role" {
  source                     = "github.com/traveloka/terraform-aws-iam-role.git//modules/service?ref=v1.0.2"
  role_identifier            = "${var.product_domain}-codepipeline-trigger"
  role_description           = "Service Role to trigger ${var.product_domain} CodePipeline pipelines"
  role_force_detach_policies = true
  role_max_session_duration  = 43200
  product_domain             = "${var.product_domain}"
  environment                = "management"

  aws_service = "events.amazonaws.com"
}

resource "aws_iam_role_policy" "events_codepipeline_policy_main" {
  name   = "${module.events_role.role_name}-main"
  role   = "${module.events_role.role_name}"
  policy = "${data.aws_iam_policy_document.events_codepipeline.json}"
}
