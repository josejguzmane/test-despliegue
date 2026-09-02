output "private_dns_zone_ids" {
  description = "Mapa zona -> ID. Lo consumen las fases 40 y 50 para sus private endpoints."
  value       = module.private_dns.zone_ids
}

output "private_dns_zone_names" {
  description = "Zonas DNS privadas creadas."
  value       = module.private_dns.zone_names
}

output "resource_group_name" {
  description = "Resource group de la capa de datos."
  value       = local.data_rg
}

output "privatelink_subnet_id" {
  description = "Subred de private endpoints heredada del spoke."
  value       = local.spoke.privatelink_subnet_id
}
