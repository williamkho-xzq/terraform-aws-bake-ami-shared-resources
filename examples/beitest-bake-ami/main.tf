provider "aws" {
  region = "ap-southeast-1"
}

module "bei" {
  source         = "../.."
  product_domain = "bei"

  vpc_id              = "vpc-abcdef01"
  base_ami_owners     = []
  lambda_function_arn = "${aws_lambda_function.share_ami.arn}"
}

module "beitest_bake_ami" {
  source = "github.com/salvianreynaldi/terraform-aws-bake-ami?ref=events-trigger"

  codepipeline_artifact_bucket = "${module.bei.codepipeline_artifact_bucket}"
  codepipeline_role_arn        = "${module.bei.codepipeline_role_arn}"
  codebuild_cache_bucket       = "${module.bei.codebuild_cache_bucket}"
  codebuild_role_arn           = "${module.bei.codebuild_role_arn}"
  lambda_function_name         = "${aws_lambda_function.share_ami.function_name}"
  template_instance_profile    = "${module.bei.template_instance_profile_name}"
  template_instance_sg         = "${module.bei.template_instance_security_group}"
  service_name                 = "beitest"
  product_domain               = "bei"
  playbook_bucket              = "${module.bei.application_binary_bucket}"
  playbook_key                 = "beitest/playbook.zip"
  ami_manifest_bucket          = "${module.bei.codepipeline_artifact_bucket}"

  base_ami_owners = [
    "123456789012",
    "234567890123",
  ]

  vpc_id    = "${module.bei.vpc_id}"
  subnet_id = "${module.bei.subnet_id}"

  buildspec = <<EOF
version: 0.2
env:
  variables:
    USER: "ubuntu"
    PACKER_NO_COLOR: "true"
    APP_TEMPLATE_SG_ID: "$${template_instance_sg}"
    APP_S3_PREFIX: "s3://$${ami_manifest_bucket}/$${ami_baking_project_name}"
    APP_TEMPLATE_INSTANCE_PROFILE: "$${template_instance_profile}"
    APP_TEMPLATE_INSTANCE_VPC_ID: "$${vpc_id}"
    APP_TEMPLATE_INSTANCE_SUBNET_ID: "$${subnet_id}"
    STACK_AMI_OWNERS: "$${base_ami_owners}"
    STACK_AMI_NAME_FILTER: "my_base_ami/*"
    PACKER_VARIABLES_FILE: "packer_variables.json"
phases:
  pre_build:
    commands:
      - ansible-galaxy install -r requirements.yml
      - packer validate -var-file=$$$${PACKER_VARIABLES_FILE} /root/aws-ebs-traveloka-ansible.json
  build:
    commands:
      - packer build -var-file=$$$${PACKER_VARIABLES_FILE} /root/aws-ebs-traveloka-ansible.json
cache:
  paths:
    - /root/.ansible/roles/**/*
artifacts:
  files:
    - packer-manifest.json
EOF
}

module "lambda_function_name" {
  source = "github.com/traveloka/terraform-aws-resource-naming.git?ref=v0.17.0"

  name_prefix = "bei-ami-sharing"
  resource_type = "lambda_function"
}

resource "aws_lambda_function" "share_ami" {
  filename = "${data.archive_file.share_ami_function.output_path}"
  source_code_hash = "${data.archive_file.share_ami_function.output_base64sha256}"
  role = "${module.lambda_role.role_arn}"
  function_name = "${module.lambda_function_name.name}"
  description = "share bei's AMIs"
  runtime = "python3.6"
  handler = "main.handler"
}

resource "aws_ssm_parameter" "target_accounts" {
  name = "ami-target-accounts"
  type = "StringList"
  value = ""
}

module "lambda_role" {
  source = "github.com/traveloka/terraform-aws-iam-role.git//modules/service?ref=v1.0.2"
  role_identifier = "ami-sharing"
  role_description = "Service Role for lambda to share bei services AMI to multiple AWS accounts"
  role_force_detach_policies = true
  role_max_session_duration = 43200

  aws_service = "lambda.amazonaws.com"
}

resource "aws_iam_role_policy" "lambda" {
  name = "${module.lambda_role.role_name}-lambda"
  role = "${module.lambda_role.role_name}"
  policy = "${data.aws_iam_policy_document.lambda_share_ami.json}"
}
