# =============================================================================
# FASE 30 - CAPA DE DATOS Y RESOLUCION PRIVADA
# =============================================================================
# Principio rector del diseno: ningun componente de datos tiene IP publica.
# Todo se consume por private endpoint en snet-privatelink, y la resolucion de
# nombres se apoya en zonas DNS privadas alojadas en el hub (seccion 3.6).
#
# Este andamiaje crea las zonas y sus vinculos a hub y spoke, que es lo unico
# sin costo fijo. Los servicios PaaS quedan detras de feature flags porque cada
# uno tiene costo mensual relevante.
#
# Las zonas viven en el resource group del hub, pero se crean en esta fase y no
# en la 10 porque necesitan el ID de la VNet del spoke para el vnet link, y el
# spoke no existe hasta la fase 20.
# =============================================================================

locals {
  phase = "30-data"
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "data"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

module "private_dns" {
  source = "../../modules/private-dns-zone"

  zones               = var.private_dns_zones
  resource_group_name = local.hub_rg
  tags                = module.naming.tags

  vnet_links = {
    hub = {
      vnet_id              = local.hub.vnet_id
      registration_enabled = false
    }
    spoke = {
      vnet_id              = local.spoke.vnet_id
      registration_enabled = false
    }
  }
}

# -----------------------------------------------------------------------------
# TODO fase 30 - cada bloque va con su private endpoint en
# local.spoke.privatelink_subnet_id y su private_dns_zone_group apuntando a la
# zona correspondiente de module.private_dns.zone_ids:
#
#   [ ] azurerm_key_vault (Premium, RBAC, purge protection, soft delete,
#       public_network_access_enabled = false)  -> privatelink.vaultcore.azure.net
#   [ ] azurerm_container_registry (Premium, cuarentena, retencion de untagged,
#       replicacion geografica) -> privatelink.azurecr.io
#   [ ] azurerm_storage_account (adjuntos: versionado, immutability policy para
#       evidencias, lifecycle Hot/Cool/Archive, shared_access_key_enabled=false)
#       -> privatelink.blob.core.windows.net
#   [ ] azurerm_postgresql_flexible_server (HA zona-redundante, CMK, PITR 35d,
#       pgaudit, RLS por tenant, replica de lectura en region secundaria)
#       -> privatelink.postgres.database.azure.com
#   [ ] azurerm_redis_cache (Premium, zona-redundante, persistencia AOF)
#       -> privatelink.redis.cache.windows.net
#   [ ] azurerm_servicebus_namespace (Premium, zona-redundante, topics
#       ticket.events / workflow.commands / notification.outbox con sesiones y
#       dead-letter) -> privatelink.servicebus.windows.net
#   [ ] azurerm_search_service (indices por tenant, busqueda vectorial)
#       -> privatelink.search.windows.net
#   [ ] Llaves administradas por el cliente (CMK) con rotacion anual
#   [ ] azurerm_monitor_diagnostic_setting de cada recurso hacia LAW
# -----------------------------------------------------------------------------

resource "terraform_data" "unimplemented_guard" {
  # Siempre presente: la guarda vive en la precondition, no en el count,
  # porque Terraform exige que la condicion referencie algo real.
  input = local.phase

  lifecycle {
    precondition {
      condition = !anytrue([
        var.enable_postgresql, var.enable_redis, var.enable_service_bus,
        var.enable_storage, var.enable_key_vault, var.enable_acr, var.enable_ai_search,
      ])
      error_message = "Hay flags de servicios de datos activos pero los recursos aun no estan implementados en esta fase. Implementa los TODO de main.tf antes de encender los flags."
    }
  }
}
