output "resource_group_names" {
  description = "Mapa componente -> nombre de resource group."
  value       = { for k, v in module.resource_group : k => v.name }
}

output "resource_group_ids" {
  description = "Mapa componente -> ID de resource group."
  value       = { for k, v in module.resource_group : k => v.id }
}

output "location" {
  description = "Region primaria del despliegue."
  value       = var.location
}

output "log_analytics_workspace_id" {
  description = "ID del workspace compartido de Log Analytics."
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Nombre del workspace compartido de Log Analytics."
  value       = azurerm_log_analytics_workspace.main.name
}

output "tags" {
  description = "Etiquetas base reutilizables por fases posteriores."
  value       = module.naming["hub"].tags
}
