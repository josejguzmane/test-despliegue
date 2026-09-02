# =============================================================================
# FASE 00 - FOUNDATION
# =============================================================================
# Crea el esqueleto sobre el que se apoyan todas las demas fases:
#   - un resource group por dominio funcional
#   - el workspace de Log Analytics compartido
#
# Se mantiene deliberadamente barato: nada aqui tiene costo fijo relevante.
# =============================================================================

locals {
  phase = "00-foundation"

  # Un RG por dominio. Facilita RBAC, Azure Policy por scope y borrado por fase.
  components = {
    hub   = "Red del hub: firewall, bastion, DNS resolver, zonas privadas"
    spoke = "Red del spoke productivo de la aplicacion"
    data  = "PostgreSQL, Redis, Service Bus, Blob, AI Search, Key Vault, ACR"
    aks   = "Cluster AKS y sus identidades"
    edge  = "Front Door, WAF, Private Link Service"
    obs   = "Log Analytics, Prometheus, Grafana, Application Insights"
    sec   = "Defender, Sentinel, definiciones de Azure Policy"
  }
}

module "naming" {
  source   = "../../modules/naming"
  for_each = local.components

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = each.key
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = merge(var.extra_tags, { description = each.value })
}

module "resource_group" {
  source   = "../../modules/resource-group"
  for_each = local.components

  name       = module.naming[each.key].resource_group
  location   = var.location
  tags       = module.naming[each.key].tags
  lock_level = var.resource_group_lock_level
}

# -----------------------------------------------------------------------------
# Log Analytics compartido. Destino de: diagnostic settings de todos los
# recursos, Container Insights, logs de auditoria de Kubernetes, WAF y Firewall
# (seccion 8). Sentinel se habilita encima en la fase 70.
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = module.naming["obs"].log_analytics_workspace
  resource_group_name = module.resource_group["obs"].name
  location            = var.location

  sku                        = "PerGB2018"
  retention_in_days          = var.log_retention_days
  daily_quota_gb             = var.log_daily_quota_gb
  internet_ingestion_enabled = true # los agentes de AKS ingestan por aqui; endurecer con AMPLS en fase 60
  internet_query_enabled     = true

  tags = module.naming["obs"].tags
}

# -----------------------------------------------------------------------------
# TODO fase 00 (cuando se llene el andamiaje):
#   - azurerm_monitor_private_link_scope (AMPLS) para que la telemetria no
#     salga a Internet, e ingestion/query solo por private endpoint.
#   - azurerm_user_assigned_identity compartida para deployment scripts.
#   - Budget de Cost Management por resource group con alertas al owner.
# -----------------------------------------------------------------------------
