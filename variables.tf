variable "product_domain" {
  description = "The product domain which the created resources belong to"
  type        = "string"
}

variable "base_ami_owners" {
  description = "The AWS account IDs that owns the base AMI"
  type        = "list"
}

variable "vpc_id" {
  description = "The id of the VPC where CodeBuild and AMI baking instances will reside"
  type        = "string"
}

variable "subnet_tier" {
  description = "The tier of the subnet where CodeBuild and AMI baking instances should run, i.e. either 'public' or 'app'"
  type        = "string"
  default     = "public"
}

variable "lambda_function_arn" {
  description = "The arn of the AMI sharing lambda function"
  type        = "string"
}

variable "appbin_writers" {
  description = "The IAM ARNs from other AWS Accounts that should be given access to write to the application binary bucket"
  type        = "list"
}

variable "appbin_expiration_days" {
  description = "The number of days before objects in the application binary bucket are deleted"
  type        = "string"
  default     = "365"
}

variable "appbin_standard_ia_transition_days" {
  description = "The number of days before objects in the application binary bucket are moved to the standard IA class"
  type        = "string"
  default     = "30"
}

variable "appbin_deep_archive_transition_days" {
  description = "The number of days before objects in the application binary bucket are moved to the glacier deep archive class"
  type        = "string"
  default     = "60"
}

variable "logging_bucket" {
  description = "The name of the bucket that will receive the log objects of all S3 resources in this module"
  type        = "string"
}
