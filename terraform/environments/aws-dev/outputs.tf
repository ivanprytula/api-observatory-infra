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
  description = "ECR registry hostname consumed by the app repository's manual CD workflow."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "github_actions_image_publish_role_arn" {
  description = "Application-repository ECR image publisher role ARN."
  value       = aws_iam_role.github_actions_image_publish.arn
}

output "github_actions_infra_deploy_role_arn" {
  description = "Infrastructure-repository desired-state deployer role ARN."
  value       = aws_iam_role.github_actions_infra_deploy.arn
}

output "stage0_runtime_parameter_path" {
  description = "SecureString Parameter Store path read by the EC2 Stage 0 instance role."
  value       = var.stage0_runtime_parameter_path
}

output "stage0_backup_bucket" {
  description = "Private S3 bucket retaining encrypted Stage 0 PostgreSQL backups."
  value       = aws_s3_bucket.stage0_backups.id
}

output "stage0_ansible_transfer_bucket" {
  description = "Private, short-lived S3 transfer bucket for the Ansible SSM connection plugin."
  value       = aws_s3_bucket.stage0_ansible_transfer.id
}
