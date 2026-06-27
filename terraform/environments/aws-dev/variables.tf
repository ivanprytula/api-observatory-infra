variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "api-observatory"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro = free tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the instance (must be a specific IP/range)"
  type        = string

  validation {
    condition     = var.admin_cidr != "*" && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a specific CIDR, not the entire internet."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

variable "pg_admin_user" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "pgadmin"
}

variable "pg_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "pg_database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "api_observatory"
}

variable "rds_instance_class" {
  description = "RDS instance class (db.t3.micro = free tier eligible)"
  type        = string
  default     = "db.t3.micro"
}
