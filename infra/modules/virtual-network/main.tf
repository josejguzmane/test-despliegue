locals {
  # Azure prohibe asociar NSG a estas subredes de servicio.
  nsg_forbidden = ["AzureFirewallSubnet", "AzureFirewallManagementSubnet", "GatewaySubnet"]

  subnets_with_nsg = {
    for k, v in var.subnets : k => v
    if v.associate_nsg && !contains(local.nsg_forbidden, k)
  }

  subnets_with_route_table = {
    for k, v in var.subnets : k => v
    if v.associate_route_table && var.route_table_id != null
  }
}

resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                              = each.key
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  private_endpoint_network_policies = each.value.private_endpoint_policies

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service
        actions = delegation.value.actions
      }
    }
  }
}

# NSG dedicado por subred, deny-all entrante implicito de Azure + reglas
# explicitas que se agregan desde la fase que lo necesita.
resource "azurerm_network_security_group" "this" {
  for_each = local.subnets_with_nsg

  name                = "nsg-${var.name}-${lower(each.key)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnets_with_nsg

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = local.subnets_with_route_table

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = var.route_table_id
}
