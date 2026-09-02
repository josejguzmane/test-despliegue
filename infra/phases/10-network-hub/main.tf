# =============================================================================
# FASE 10 - RED DEL HUB
# =============================================================================
# Topologia hub-spoke (seccion 3.1). Aqui vive todo lo compartido: firewall de
# egreso, acceso administrativo por Bastion, resolucion DNS privada y el
# gateway hacia on-premises.
#
# En este andamiaje se crean solo los recursos sin costo fijo (VNet, subredes,
# NSG). Firewall, Bastion y DNS Resolver quedan detras de feature flags para
# que el pipeline se pueda ejercitar end-to-end a costo cercano a cero.
# =============================================================================

locals {
  phase = "10-network-hub"

  subnets = {
    # Nombres obligatorios de Azure. Estas subredes no admiten NSG.
    AzureFirewallSubnet = {
      address_prefixes = [var.hub_subnets["firewall"]]
      associate_nsg    = false
    }
    AzureFirewallManagementSubnet = {
      address_prefixes = [var.hub_subnets["firewall_management"]]
      associate_nsg    = false
    }
    GatewaySubnet = {
      address_prefixes = [var.hub_subnets["gateway"]]
      associate_nsg    = false
    }
    # Bastion exige un set de reglas NSG especifico. Se agrega junto con el
    # recurso Bastion, no antes, para no dejar una subred inutilizable.
    AzureBastionSubnet = {
      address_prefixes = [var.hub_subnets["bastion"]]
      associate_nsg    = false
    }
    "snet-dns-inbound" = {
      address_prefixes = [var.hub_subnets["dns_inbound"]]
      associate_nsg    = true
      delegation = {
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    "snet-dns-outbound" = {
      address_prefixes = [var.hub_subnets["dns_outbound"]]
      associate_nsg    = true
      delegation = {
        name    = "Microsoft.Network.dnsResolvers"
        service = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    "snet-mgmt" = {
      address_prefixes = [var.hub_subnets["mgmt"]]
      associate_nsg    = true
    }
  }
}

module "naming" {
  source = "../../modules/naming"

  prefix      = var.prefix
  environment = var.environment
  location    = var.location
  component   = "hub"
  cost_center = var.cost_center
  owner       = var.owner
  phase       = local.phase
  extra_tags  = var.extra_tags
}

module "vnet" {
  source = "../../modules/virtual-network"

  name                = module.naming.virtual_network
  resource_group_name = local.hub_rg
  location            = var.location
  address_space       = var.hub_address_space
  subnets             = local.subnets
  tags                = module.naming.tags
}

# -----------------------------------------------------------------------------
# TODO fase 10 - rellenar cuando se apruebe el presupuesto:
#
#   [ ] azurerm_public_ip "pip-fw" (Standard, zonal 1/2/3)
#   [ ] azurerm_firewall_policy "fwp" (Premium, IDPS + TLS inspection con CA
#       intermedia en Key Vault)
#   [ ] azurerm_firewall_policy_rule_collection_group con las reglas de la
#       tabla 3.4: service tag AzureCloud 443/9000/1194, NTP UDP 123, FQDN tag
#       AzureKubernetesService, *.azurecr.io, *.blob.core.windows.net, relay
#       SMTP y lista blanca de integradores
#   [ ] azurerm_firewall "fw" (Premium, forced tunneling, zonas 1/2/3)
#   [ ] azurerm_bastion_host "bas" (Standard, native client, tunneling)
#   [ ] Reglas NSG obligatorias de AzureBastionSubnet
#   [ ] azurerm_private_dns_resolver + inbound/outbound endpoints y ruleset
#   [ ] azurerm_virtual_network_gateway "vgw" (VPN S2S / ExpressRoute)
#   [ ] azurerm_network_ddos_protection_plan (compartido por tenant)
#   [ ] azurerm_monitor_diagnostic_setting de firewall y VNet hacia LAW
#
# Al crear el firewall, cambiar el output firewall_private_ip por
# azurerm_firewall.fw.ip_configuration[0].private_ip_address
# -----------------------------------------------------------------------------

# Guarda: los flags de costo alto no deben encenderse antes de que exista el
# codigo correspondiente. Falla en plan, no en apply.
resource "terraform_data" "unimplemented_guard" {
  # Siempre presente: la guarda vive en la precondition, no en el count,
  # porque Terraform exige que la condicion referencie algo real.
  input = local.phase

  lifecycle {
    precondition {
      condition     = !(var.enable_firewall || var.enable_bastion || var.enable_dns_resolver)
      error_message = "enable_firewall / enable_bastion / enable_dns_resolver estan activos pero los recursos aun no estan implementados. Implementa los TODO de main.tf antes de encender los flags."
    }
  }
}
