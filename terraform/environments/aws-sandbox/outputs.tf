output "vpc_id" {
  description = "VPC ID (LocalStack)"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "App security group ID (LocalStack)"
  value       = aws_security_group.app.id
}
