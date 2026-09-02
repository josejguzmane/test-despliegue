output "policy_assignment_ids" {
  description = "Mapa asignacion|componente -> ID de la asignacion de Azure Policy."
  value       = { for k, v in azurerm_resource_group_policy_assignment.this : k => v.id }
}

output "policy_assignments_enforcing" {
  description = "Asignaciones que estan bloqueando de verdad (enforce = true)."
  value       = [for k, v in local.policy_scopes : k if v.config.enforce]
}

output "resource_group_name" {
  description = "Resource group de seguridad."
  value       = local.sec_rg
}
