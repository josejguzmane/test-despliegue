package main

import data.terraform.common
import rego.v1

# El diseno es explicito: cero secretos en el cluster y cero service principals
# con secreto en variables (secciones 4.3 y 9). Estos atributos no deberian
# aparecer nunca en un plan.
forbidden_attributes := {
	"administrator_password",
	"admin_password",
	"client_secret",
	"primary_access_key",
	"secret_value",
}

deny contains msg if {
	some r in common.changed_resources
	some attr in forbidden_attributes
	value := object.get(common.after(r), attr, null)
	value != null
	is_string(value)
	value != ""
	msg := sprintf("%s.%s define '%s' en el plan. Usar Key Vault, Workload Identity o autenticacion por Entra ID.", [r.type, r.name, attr])
}

# Los service principals de CI no deben tener password.
deny contains msg if {
	some r in common.changed_resources
	r.type in {"azuread_application_password", "azuread_service_principal_password"}
	msg := sprintf("%s.%s crea un secreto de cliente. El pipeline usa federacion OIDC, no secretos.", [r.type, r.name])
}
