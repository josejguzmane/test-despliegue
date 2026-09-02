output "vnet_id" {
  description = "ID de la VNet hub."
  value       = module.vnet.id
}

output "vnet_name" {
  description = "Nombre de la VNet hub."
  value       = module.vnet.name
}

output "resource_group_name" {
  description = "Resource group del hub. Aloja tambien las zonas DNS privadas."
  value       = local.hub_rg
}

output "subnet_ids" {
  description = "Mapa subred -> ID en el hub."
  value       = module.vnet.subnet_ids
}

output "address_space" {
  description = "CIDRs de la VNet hub."
  value       = module.vnet.address_space
}

output "firewall_private_ip" {
  description = "IP privada del Azure Firewall. null mientras el firewall no exista; en ese caso la fase 20 omite la UDR de egreso."
  value       = var.firewall_private_ip_override
}
