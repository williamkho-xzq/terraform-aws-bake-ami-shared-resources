output "codepipeline_role_arn" {
  value = module.codepipeline_role.role_arn
}

output "codebuild_role_arn" {
  value = module.codebuild_role.role_arn
}

output "events_role_arn" {
  value = module.events_role.role_arn
}

output "template_instance_profile_name" {
  value = module.template_instance_role.instance_profile_name
}

output "template_instance_security_group" {
  value = aws_security_group.template.id
}

output "codepipeline_artifact_bucket" {
  value = aws_s3_bucket.codepipeline_artifact.id
}

output "application_binary_bucket" {
  value = aws_s3_bucket.application_binary.id
}

output "application_binary_bucket_arn" {
  value = aws_s3_bucket.application_binary.arn
}

output "codebuild_cache_bucket" {
  value = aws_s3_bucket.codebuild_cache.id
}

output "subnet_id" {
  value = data.aws_subnet.selected.id
}

output "vpc_id" {
  value = data.aws_vpc.selected.id
}
