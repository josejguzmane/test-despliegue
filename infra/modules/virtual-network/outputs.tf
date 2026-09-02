output "id" {
  description = "ID de la VNet."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Nombre de la VNet."
  value       = azurerm_virtual_network.this.name
}

output "address_space" {
  description = "CIDRs de la VNet."
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "Mapa nombre-de-subred -> ID."
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}

output "subnet_prefixes" {
  description = "Mapa nombre-de-subred -> CIDRs."
  value       = { for k, v in azurerm_subnet.this : k => v.address_prefixes }
}

output "nsg_ids" {
  description = "Mapa nombre-de-subred -> ID del NSG asociado."
  value       = { for k, v in azurerm_network_security_group.this : k => v.id }
}
