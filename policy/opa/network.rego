package main

import data.terraform.common
import rego.v1

# Ningun componente de computo o datos puede tener IP publica: el unico punto de
# entrada desde Internet es Front Door (seccion 2). Las IPs publicas del hub
# (firewall, bastion, gateway) son la excepcion legitima.
hub_public_ip_names := {"pip-fw", "pip-bas", "pip-vgw"}

deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_public_ip"
	name := object.get(common.after(r), "name", "")
	not startswith_any(name, hub_public_ip_names)
	msg := sprintf("azurerm_public_ip.%s crea una IP publica '%s'. Solo el hub puede tener IPs publicas (firewall, bastion, gateway).", [r.name, name])
}

startswith_any(value, prefixes) if {
	some p in prefixes
	startswith(value, p)
}

# Nada de administracion expuesta a Internet.
management_ports := {"22", "3389", "5432", "6379", "1433"}

deny contains msg if {
	some r in common.changed_resources
	r.type in {"azurerm_network_security_rule", "azurerm_network_security_group"}
	rule := security_rules(r)[_]
	rule.direction == "Inbound"
	rule.access == "Allow"
	rule.source_address_prefix in {"*", "0.0.0.0/0", "Internet"}
	port := rule.destination_port_range
	port in management_ports
	msg := sprintf("%s.%s: regla '%s' abre el puerto %s a Internet.", [r.type, r.name, object.get(rule, "name", "?"), port])
}

security_rules(r) := rules if {
	r.type == "azurerm_network_security_group"
	rules := object.get(common.after(r), "security_rule", [])
}

security_rules(r) := [common.after(r)] if {
	r.type == "azurerm_network_security_rule"
}

# El cluster de AKS debe ser privado y el egreso forzado por UDR (seccion 3.4).
deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_kubernetes_cluster"
	object.get(common.after(r), "private_cluster_enabled", false) != true
	msg := sprintf("azurerm_kubernetes_cluster.%s no tiene private_cluster_enabled = true.", [r.name])
}

deny contains msg if {
	some r in common.changed_resources
	r.type == "azurerm_kubernetes_cluster"
	profile := object.get(common.after(r), "network_profile", [{}])[0]
	object.get(profile, "outbound_type", "loadBalancer") != "userDefinedRouting"
	msg := sprintf("azurerm_kubernetes_cluster.%s no usa outbound_type = userDefinedRouting: el egreso no pasaria por el firewall.", [r.name])
}
