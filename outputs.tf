output "id" {
  value = azurerm_virtual_machine.main.id
}

output "private_ip" {
  value = azurerm_network_interface.main.private_ip_address
}

output "public_ip" {
  value = var.public_ip ? azurerm_public_ip.main[0].ip_address : null
}

output "admin_password" {
  value = var.admin_password == null ? random_string.admin_password.result : var.admin_password
}

output "network_interface_id" {
  value = azurerm_network_interface.main.id
}
