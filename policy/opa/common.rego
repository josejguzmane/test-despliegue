package terraform.common

import rego.v1

# Recursos que el plan va a crear o modificar. Los destroy y los no-op no
# necesitan validarse.
changed_resources contains r if {
	some r in input.resource_changes
	actions := r.change.actions
	some a in actions
	a in {"create", "update"}
}

# Valor resultante tras aplicar el cambio.
after(r) := r.change.after
