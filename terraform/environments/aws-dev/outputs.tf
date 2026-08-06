output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ecr_registry" {
  description = "ECR registry hostname consumed by the app repository's MVP workflows."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "github_actions_image_publish_role_arn" {
  description = "Application-repository ECR image publisher role ARN."
  value       = aws_iam_role.github_actions_image_publish.arn
}

output "github_actions_app_deploy_role_arn" {
  description = "Application-repository workload-deployer role ARN."
  value       = aws_iam_role.github_actions_app_deploy.arn
}

output "mvp_runtime_parameter_path" {
  description = "SecureString Parameter Store path read by the EC2 MVP instance role."
  value       = var.mvp_runtime_parameter_path
}

output "mvp_backup_bucket" {
  description = "Private S3 bucket retaining encrypted MVP PostgreSQL backups."
  value       = aws_s3_bucket.mvp_backups.id
}

output "mvp_ansible_transfer_bucket" {
  description = "Private, short-lived S3 transfer bucket for the Ansible SSM connection plugin."
  value       = aws_s3_bucket.mvp_ansible_transfer.id
}
