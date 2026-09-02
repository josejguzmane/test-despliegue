# =============================================================================
# FASE 20 - RED DEL SPOKE DE APLICACION
# =============================================================================
# Spoke productivo (seccion 3.2). Contiene las subredes de AKS, ingress, APIM y
# private endpoints, la route table de egreso forzado hacia el firewall
# (seccion 3.4) y el peering bidireccional con el hub.
#
# Los spokes no se emparejan entre si: todo trafico inter-spoke pasa por el
# firewall del hub.
# =============================================================================

locals {
  phase = "20-network-spoke"

  # El egreso forzado solo se puede declarar cuando el firewall ya tiene IP.
  # Mientras no exista, la subred sale por el default de Azure y la fase sigue
  # siendo aplicable.
  firewall_ip       = local.hub.firewall_private_ip
  egress_via_fw     = local.firewall_ip != null
  route_table_id_in = local.egress_via_fw ? azurerm_route_table.spoke[0].id : null

  subnets = {
    "snet-aks-system" = {
      address_prefixes      = [var.spoke_subnets["aks_system"]]
      associate_nsg         = true
      associate_route_table = true
    }
    "snet-aks-user" = {
      address_prefixes      = [var.spoke_subnets["aks_user"]]
      associate_nsg         = true
      associate_route_table = true
    }
    "snet-ingress" = {
      address_prefixes      = [var.spoke_subnets["ingress"]]
      associate_nsg         = true
      associate_route_table = true
      # El Private Link Service que publica el ILB del ingress exige
      # deshabilitar las network policies de private link en su subred.
      private_endpoint_policies = "Disabled"
    }
    "snet-apim" = {
      address_prefixes      = [var.spoke_subnets["apim"]]
      associate_nsg         = true
      associate_route_table = true
    }
    "snet-privatelink" = {
      address_prefixes          = [var.spoke_subnets["privatelink"]]
      associate_nsg             = true
      associate_route_table     = false
      private_endpoint_policies = "Disabled"
    }
  }
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "spoke"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

# -----------------------------------------------------------------------------
# Egreso controlado (seccion 3.4): 0.0.0.0/0 hacia la IP privada del firewall.
# Los node pools de AKS usan outboundType = userDefinedRouting apoyandose en
# esta ruta, de modo que un pod comprometido no puede exfiltrar a destinos
# arbitrarios.
# -----------------------------------------------------------------------------
resource "azurerm_route_table" "spoke" {
  count = local.egress_via_fw ? 1 : 0

  name                = module.naming.route_table
  resource_group_name = local.spoke_rg
  location            = var.location
  tags                = module.naming.tags

  # Sin esto, rutas aprendidas por BGP podrian saltarse el firewall.
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "default_via_firewall" {
  count = local.egress_via_fw ? 1 : 0

  name                   = "default-to-firewall"
  resource_group_name    = local.spoke_rg
  route_table_name       = azurerm_route_table.spoke[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.firewall_ip
}

module "vnet" {
  source = "../../modules/virtual-network"

  name                = module.naming.virtual_network
  resource_group_name = local.spoke_rg
  location            = var.location
  address_space       = var.spoke_address_space
  subnets             = local.subnets
  route_table_id      = local.route_table_id_in
  tags                = module.naming.tags

  # Cuando exista el DNS Private Resolver del hub, apuntar aqui su inbound
  # endpoint para que el spoke resuelva las zonas privatelink.* (seccion 3.6).
  dns_servers = []
}

# -----------------------------------------------------------------------------
# Peering hub <-> spoke. allowForwardedTraffic habilitado en ambos sentidos: el
# trafico que sale del spoke vuelve del firewall conservando la IP de origen
# original y seria descartado sin este flag.
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = var.enable_peering ? 1 : 0

  name                      = "peer-spoke-to-hub"
  resource_group_name       = local.spoke_rg
  virtual_network_name      = module.vnet.name
  remote_virtual_network_id = local.hub.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count = var.enable_peering ? 1 : 0

  name                      = "peer-hub-to-${module.naming.base}"
  resource_group_name       = local.hub_rg
  virtual_network_name      = local.hub.vnet_name
  remote_virtual_network_id = module.vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  # El hub publica su gateway hacia los spokes cuando exista.
  allow_gateway_transit = var.use_remote_gateways
  use_remote_gateways   = false
}

# -----------------------------------------------------------------------------
# TODO fase 20:
#   [ ] Reglas NSG explicitas por subred (deny-all entrante mas lo necesario)
#   [ ] NSG flow logs v2 hacia Storage con Traffic Analytics en LAW
#   [ ] azurerm_private_link_service del ILB del ingress: se crea en la fase 50
#       porque depende del ILB que publica el ingress controller
#   [ ] Delegacion de snet-apim si se usa APIM en modo stv2
#   [ ] azurerm_monitor_diagnostic_setting de la VNet hacia LAW
# -----------------------------------------------------------------------------
