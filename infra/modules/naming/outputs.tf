output "base" {
  description = "Sufijo base con guiones: <prefix>-<component>-<env>-<loc>."
  value       = local.base
}

output "compact" {
  description = "Sufijo base sin guiones, para recursos con nombres restringidos."
  value       = local.compact
}

output "location_short" {
  description = "Abreviatura de la region."
  value       = local.location_short
}

output "resource_group" {
  description = "Nombre del resource group."
  value       = "rg-${local.base}"
}

output "virtual_network" {
  description = "Nombre de la VNet."
  value       = "vnet-${local.base}"
}

output "route_table" {
  description = "Nombre de la route table."
  value       = "rt-${local.base}"
}

output "network_security_group" {
  description = "Nombre base del NSG."
  value       = "nsg-${local.base}"
}

output "log_analytics_workspace" {
  description = "Nombre del workspace de Log Analytics."
  value       = "log-${local.base}"
}

output "tags" {
  description = "Etiquetas estandar de la plataforma."
  value       = local.tags
}
