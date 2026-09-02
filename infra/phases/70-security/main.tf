# =============================================================================
# FASE 70 - GOBIERNO Y SEGURIDAD
# =============================================================================
# Azure Policy en modo deny (seccion 4.4), Defender for Cloud y Sentinel.
#
# Va al final a proposito: una policy de deny aplicada antes de que existan los
# recursos de las fases anteriores bloquearia su propio despliegue. El orden
# correcto es crear la plataforma, verificarla y despues sellarla.
#
# Las asignaciones se declaran en tfvars y arrancan con enforce = false
# (DoNotEnforce): primero se mide el impacto real sobre el inventario existente
# y solo entonces se pasa a bloqueo.
# =============================================================================

locals {
  phase = "70-security"

  # Producto asignacion x scope, aplanado para el for_each.
  policy_scopes = merge([
    for name, cfg in var.policy_assignments : {
      for component in cfg.scope_components :
      "${name}|${component}" => {
        assignment = name
        component  = component
        config     = cfg
      }
    }
  ]...)
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "sec"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

# La definicion se resuelve por display name en tiempo de plan. Si el nombre no
# existe, el plan falla con un mensaje claro en vez de crear una asignacion rota.
data "azurerm_policy_definition" "builtin" {
  for_each = var.policy_assignments

  display_name = each.value.display_name
}

resource "azurerm_resource_group_policy_assignment" "this" {
  for_each = local.policy_scopes

  name                 = substr("${each.value.assignment}-${each.value.component}", 0, 24)
  display_name         = "${each.value.config.display_name} (${each.value.component})"
  resource_group_id    = local.all_rgs[each.value.component]
  policy_definition_id = data.azurerm_policy_definition.builtin[each.value.assignment].id
  enforce              = each.value.config.enforce
  description          = "Gestionado por Terraform, fase 70-security."

  parameters = length(each.value.config.parameters) == 0 ? null : jsonencode({
    for k, v in each.value.config.parameters : k => { value = v }
  })
}

# -----------------------------------------------------------------------------
# TODO fase 70:
#
#   [ ] azurerm_security_center_subscription_pricing por plan: Containers,
#       StorageAccounts, OpenSourceRelationalDatabases, KeyVaults, Arm, Api
#   [ ] azurerm_security_center_workspace apuntando al LAW de la fase 00
#   [ ] azurerm_sentinel_log_analytics_workspace_onboarding
#   [ ] azurerm_sentinel_alert_rule_scheduled: fuerza bruta en Entra External ID,
#       salidas anomalas del firewall, escalamiento de privilegios en Kubernetes,
#       accesos a Key Vault fuera de horario
#   [ ] azurerm_sentinel_data_connector_* para Entra ID, Defender y Azure Activity
#   [ ] Playbooks de respuesta (Logic Apps) para aislar un pod o revocar sesion
#   [ ] Storage inmutable con retencion legal de 2 anos para la auditoria
#   [ ] Azure Policy for AKS (Gatekeeper): PSS restricted, deny de privileged,
#       hostNetwork, hostPID, docker.sock y registries fuera de la lista blanca
#   [ ] Ratify para verificacion de firma Cosign/Notation en admision
# -----------------------------------------------------------------------------

resource "terraform_data" "unimplemented_guard" {
  # Siempre presente: la guarda vive en la precondition, no en el count,
  # porque Terraform exige que la condicion referencie algo real.
  input = local.phase

  lifecycle {
    precondition {
      condition     = !(var.enable_defender_plans || var.enable_sentinel)
      error_message = "enable_defender_plans / enable_sentinel estan activos pero los recursos aun no estan implementados. Implementa los TODO de main.tf antes de encender los flags."
    }
  }
}
