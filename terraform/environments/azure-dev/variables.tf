variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "api-observatory-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "polandcentral"
}

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "api-observatory"
}

variable "vm_size" {
  description = "VM SKU (B1s = 750 hrs/month free)"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "VM admin SSH username"
  type        = string
  default     = "azureuser"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the VM (must be a specific IP/range)"
  type        = string

  validation {
    condition     = var.admin_cidr != "*" && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a specific CIDR, not the entire internet."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
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
