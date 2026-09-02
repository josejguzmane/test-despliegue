output "application_insights_id" {
  description = "ID del recurso de Application Insights."
  value       = azurerm_application_insights.main.id
}

output "application_insights_connection_string" {
  description = "Connection string para el colector de OpenTelemetry. Sensible: no imprimir en logs de CI."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "action_group_id" {
  description = "Grupo de accion al que apuntan todas las alertas de plataforma."
  value       = azurerm_monitor_action_group.platform.id
}

output "resource_group_name" {
  description = "Resource group de observabilidad."
  value       = local.obs_rg
}
