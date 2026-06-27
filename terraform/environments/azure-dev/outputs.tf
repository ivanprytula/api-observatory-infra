output "vm_public_ip" {
  description = "Public IP of the application VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "pg_host" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "pg_connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql+asyncpg://${var.pg_admin_user}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.pg_database_name}?sslmode=require"
  sensitive   = true
}
