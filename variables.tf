variable "product_domain" {
  type        = "string"
  description = "The product domain which the created resources belong to"
}

variable "base_ami_owners" {
  type        = "list"
  description = "The AWS account IDs that owns the base AMI"
}

variable "vpc_id" {
  type        = "string"
  description = "The id of the VPC where CodeBuild and AMI baking instances will reside"
}

variable "subnet_tier" {
  description = "The tier of the subnet where CodeBuild and AMI baking instances should run, i.e. either 'public' or 'app'"
  default     = "app"
}

variable "lambda_function_arn" {
  description = "The arn of the AMI sharing lambda function"
}

variable "appbin_writers" {
  description = "The IAM ARNs from other AWS Accounts that should be given access to write to the application binary bucket"
  type        = "list"
}
