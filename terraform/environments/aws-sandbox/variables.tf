variable "aws_region" {
  description = "AWS region (LocalStack ignores this but required by provider)"
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "api-observatory"
}

variable "admin_cidr" {
  description = "CIDR block allowed to SSH into the sandbox instance"
  type        = string
  default     = "10.0.0.0/16"
}
