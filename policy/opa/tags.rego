package main

import data.terraform.common
import rego.v1

# Etiquetas obligatorias (seccion 4.4 del diseno: Azure Policy deniega recursos
# sin etiqueta de centro de costo). Se valida antes de llegar a Azure para que
# el fallo aparezca en el PR y no a mitad del apply.
required_tags := {"costCenter", "owner", "environment", "managedBy"}

# Tipos que no aceptan tags en Azure: no tiene sentido exigirselas.
untaggable := {
	"azurerm_subnet",
	"azurerm_route",
	"azurerm_virtual_network_peering",
	"azurerm_subnet_network_security_group_association",
	"azurerm_subnet_route_table_association",
	"azurerm_management_lock",
	"azurerm_role_assignment",
	"azurerm_federated_identity_credential",
	"azurerm_resource_group_policy_assignment",
	"terraform_data",
}

deny contains msg if {
	some r in common.changed_resources
	startswith(r.type, "azurerm_")
	not r.type in untaggable
	tags := object.get(common.after(r), "tags", {})
	missing := required_tags - {k | some k, _ in tags}
	count(missing) > 0
	msg := sprintf("%s.%s: faltan etiquetas obligatorias %v", [r.type, r.name, missing])
}
