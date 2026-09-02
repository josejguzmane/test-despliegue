output "vnet_id" {
  description = "ID de la VNet spoke."
  value       = module.vnet.id
}

output "vnet_name" {
  description = "Nombre de la VNet spoke."
  value       = module.vnet.name
}

output "resource_group_name" {
  description = "Resource group del spoke."
  value       = local.spoke_rg
}

output "subnet_ids" {
  description = "Mapa subred -> ID en el spoke."
  value       = module.vnet.subnet_ids
}

output "privatelink_subnet_id" {
  description = "Subred donde aterrizan todos los private endpoints (fase 30)."
  value       = module.vnet.subnet_ids["snet-privatelink"]
}

output "aks_system_subnet_id" {
  description = "Subred del node pool de sistema (fase 40)."
  value       = module.vnet.subnet_ids["snet-aks-system"]
}

output "aks_user_subnet_id" {
  description = "Subred de los node pools de aplicacion (fase 40)."
  value       = module.vnet.subnet_ids["snet-aks-user"]
}

output "ingress_subnet_id" {
  description = "Subred del ILB interno y del Private Link Service (fase 50)."
  value       = module.vnet.subnet_ids["snet-ingress"]
}

output "egress_via_firewall" {
  description = "true si el egreso ya esta forzado por UDR hacia el firewall."
  value       = local.egress_via_fw
}
