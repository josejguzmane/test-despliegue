package main

import data.terraform.common
import rego.v1

# Ningun servicio de datos con acceso publico de red: todo por private endpoint
# en snet-privatelink (seccion 6).
private_only_types := {
	"azurerm_storage_account",
	"azurerm_key_vault",
	"azurerm_container_registry",
	"azurerm_postgresql_flexible_server",
	"azurerm_redis_cache",
	"azurerm_servicebus_namespace",
	"azurerm_search_service",
	"azurerm_cognitive_account",
}

deny contains msg if {
	some r in common.changed_resources
	r.type in private_only_types
	object.get(common.after(r), "public_network_access_enabled", true) == true
	msg := sprintf("%s.%s tiene public_network_access_enabled = true. Todo servicio de datos se consume por private endpoint.", [r.type, r.name])
}

# Storage: sin acceso anonimo, sin shared keys, TLS moderno.
deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_storage_account"
	object.get(common.after(r), "allow_nested_items_to_be_public", true) == true
	msg := sprintf("azurerm_storage_account.%s permite blobs publicos.", [r.name])
}

deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_storage_account"
	object.get(common.after(r), "shared_access_key_enabled", true) == true
	msg := sprintf("azurerm_storage_account.%s tiene shared_access_key_enabled = true. Usar solo identidad de Entra ID.", [r.name])
}

deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_storage_account"
	object.get(common.after(r), "min_tls_version", "TLS1_0") != "TLS1_2"
	msg := sprintf("azurerm_storage_account.%s no exige TLS 1.2 como minimo.", [r.name])
}

# Key Vault: RBAC, purge protection y soft delete (seccion 4.5).
deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_key_vault"
	object.get(common.after(r), "purge_protection_enabled", false) != true
	msg := sprintf("azurerm_key_vault.%s no tiene purge_protection_enabled.", [r.name])
}

deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_key_vault"
	object.get(common.after(r), "enable_rbac_authorization", false) != true
	msg := sprintf("azurerm_key_vault.%s usa access policies en vez de RBAC.", [r.name])
}

# PostgreSQL: retencion de PITR suficiente para el requisito de 35 dias.
warn contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_postgresql_flexible_server"
	object.get(common.after(r), "backup_retention_days", 7) < 35
	msg := sprintf("azurerm_postgresql_flexible_server.%s tiene menos de 35 dias de PITR (seccion 6).", [r.name])
}
