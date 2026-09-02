output "resource_group_name" {
  description = "Resource group del borde."
  value       = local.edge_rg
}

output "public_hostname" {
  description = "Nombre publico configurado para el portal."
  value       = var.public_hostname
}

output "front_door_endpoint" {
  description = "Hostname del endpoint de Front Door. null mientras el borde no este implementado."
  value       = null
}
