variable "zones" {
  description = "Lista de zonas DNS privadas (ej. privatelink.postgres.database.azure.com)."
  type        = list(string)
}

variable "resource_group_name" {
  description = "Resource group donde viven las zonas. Por diseno: el del hub."
  type        = string
}

variable "vnet_links" {
  description = <<-EOT
    VNets a ligar a cada zona. Clave = nombre logico del link,
    valor = { vnet_id, registration_enabled }.
  EOT
  type = map(object({
    vnet_id              = string
    registration_enabled = optional(bool, false)
  }))
  default = {}
}

variable "tags" {
  description = "Etiquetas."
  type        = map(string)
}

locals {
  # Producto cartesiano zona x vnet, con clave estable para el for_each.
  links = {
    for pair in setproduct(var.zones, keys(var.vnet_links)) :
    "${pair[0]}|${pair[1]}" => {
      zone      = pair[0]
      link_name = pair[1]
    }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = toset(var.zones)

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.links

  # El nombre del link debe ser unico dentro de la zona, no globalmente.
  name                  = "link-${each.value.link_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone].name
  virtual_network_id    = var.vnet_links[each.value.link_name].vnet_id
  registration_enabled  = var.vnet_links[each.value.link_name].registration_enabled
  tags                  = var.tags
}

output "zone_ids" {
  description = "Mapa nombre-de-zona -> ID."
  value       = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}

output "zone_names" {
  description = "Nombres de las zonas creadas."
  value       = keys(azurerm_private_dns_zone.this)
}
