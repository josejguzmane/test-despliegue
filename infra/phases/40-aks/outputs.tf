output "cluster_identity_id" {
  description = "ID de la identidad administrada del plano de control del cluster."
  value       = azurerm_user_assigned_identity.cluster.id
}

output "cluster_identity_principal_id" {
  description = "Principal ID de la identidad del cluster, para role assignments."
  value       = azurerm_user_assigned_identity.cluster.principal_id
}

output "kubelet_identity_client_id" {
  description = "Client ID de la identidad del kubelet, necesaria para AcrPull."
  value       = azurerm_user_assigned_identity.kubelet.client_id
}

output "workload_identity_client_ids" {
  description = "Mapa servicio -> client ID. Es el valor de la anotacion azure.workload.identity/client-id del ServiceAccount."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.client_id }
}

output "resource_group_name" {
  description = "Resource group del cluster."
  value       = local.aks_rg
}
