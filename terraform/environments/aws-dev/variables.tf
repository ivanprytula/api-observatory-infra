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
  description = "EC2 instance type for the temporary Stage 0 host"
  type        = string
  default     = "t2.micro"
}

variable "app_github_repository" {
  description = "Application repository allowed to publish immutable images."
  type        = string
  default     = "ivanprytula/api-observatory"
}

variable "infra_github_repository" {
  description = "Infrastructure repository allowed to deploy desired state."
  type        = string
  default     = "ivanprytula/api-observatory-infra"
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Leave null for Terraform to create it."
  type        = string
  default     = null
  nullable    = true
}

variable "stage0_runtime_parameter_path" {
  description = "Parameter Store path that holds service-scoped Stage 0 runtime variables."
  type        = string
  default     = "/api-observatory/aws-dev/runtime"

  validation {
    condition     = startswith(var.stage0_runtime_parameter_path, "/")
    error_message = "stage0_runtime_parameter_path must begin with '/'."
  }
}

variable "root_volume_size" {
  type    = number
  default = 30
}
