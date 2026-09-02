# =============================================================================
# FASE 60 - OBSERVABILIDAD
# =============================================================================
# Cuatro senales con destino propio (seccion 8): metricas a Managed Prometheus
# con dashboards en Managed Grafana, logs a Log Analytics, trazas por
# OpenTelemetry hacia Application Insights, y perfilado continuo.
#
# El workspace de Log Analytics ya existe desde la fase 00: aqui se cuelga todo
# lo demas.
# =============================================================================

locals {
  phase = "60-observability"
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "obs"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

# Application Insights en modo workspace-based. Sin ingesta no cuesta nada, y
# tener la connection string desde el inicio desbloquea a los equipos de
# aplicacion para instrumentar con OpenTelemetry.
resource "azurerm_application_insights" "main" {
  name                = "appi-${module.naming.base}"
  resource_group_name = local.obs_rg
  location            = var.location
  workspace_id        = local.law_id
  application_type    = "web"

  # El muestreo se controla en el SDK/colector, no aqui, para no perder trazas
  # de error. En no productivos se baja al 20% (seccion 12).
  sampling_percentage = 100

  tags = module.naming.tags
}

# Grupo de accion unico para todas las alertas de plataforma. Gratis.
resource "azurerm_monitor_action_group" "platform" {
  name                = "ag-${module.naming.base}"
  resource_group_name = local.obs_rg
  short_name          = substr("${var.prefix}${var.environment}", 0, 12)
  tags                = module.naming.tags

  dynamic "email_receiver" {
    for_each = toset(var.alert_emails)
    content {
      name                    = replace(email_receiver.value, "/[^A-Za-z0-9]/", "-")
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# -----------------------------------------------------------------------------
# TODO fase 60:
#
#   [ ] azurerm_monitor_workspace (Managed Prometheus) y su
#       azurerm_monitor_data_collection_rule/Endpoint para el scraping de AKS
#   [ ] azurerm_dashboard_grafana (Managed Grafana) con la identidad asignada y
#       rol Monitoring Reader sobre la suscripcion; datasource al workspace de
#       Prometheus y a Log Analytics
#   [ ] azurerm_monitor_data_collection_rule de Container Insights asociada al
#       cluster de la fase 40
#   [ ] Alertas de burn rate multiventana (1h/6h) por cada SLO de var.slo_targets:
#       disponibilidad del portal 99.9%, p95 de creacion de ticket < 800 ms,
#       p99 de API < 2 s, antiguedad en cola de workflow < 60 s, 5xx < 0.1%
#   [ ] azurerm_monitor_scheduled_query_rules_alert_v2 apuntadas al action group
#   [ ] azurerm_monitor_private_link_scope para que la telemetria no salga a
#       Internet
#   [ ] Dashboards de negocio (tickets abiertos por cola, cumplimiento de SLA) y
#       de plataforma (USE/RED) versionados como JSON en este repositorio
# -----------------------------------------------------------------------------

resource "terraform_data" "unimplemented_guard" {
  # Siempre presente: la guarda vive en la precondition, no en el count,
  # porque Terraform exige que la condicion referencie algo real.
  input = local.phase

  lifecycle {
    precondition {
      condition     = !(var.enable_grafana || var.enable_managed_prometheus)
      error_message = "enable_grafana / enable_managed_prometheus estan activos pero los recursos aun no estan implementados. Implementa los TODO de main.tf antes de encender los flags."
    }
  }
}
