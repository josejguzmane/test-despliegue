variable "hub_address_space" {
  description = "CIDR de la VNet hub. Diseno: 10.0.0.0/22."
  type        = list(string)
}

variable "hub_subnets" {
  description = "Subredes del hub. Las claves AzureFirewallSubnet, AzureFirewallManagementSubnet, AzureBastionSubnet y GatewaySubnet son nombres obligatorios de Azure."
  type        = map(string)
}

variable "enable_firewall" {
  description = "Crea Azure Firewall Premium. COSTO ALTO (~900 USD/mes). Dejar en false mientras el andamiaje se valida."
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Crea Azure Bastion. COSTO MEDIO (~140 USD/mes en SKU Standard)."
  type        = bool
  default     = false
}

variable "enable_dns_resolver" {
  description = "Crea el DNS Private Resolver del hub. COSTO BAJO (~180 USD/mes por endpoint)."
  type        = bool
  default     = false
}

variable "firewall_private_ip_override" {
  description = "IP privada del firewall cuando este se gestiona fuera de esta fase. Si es null, la fase 20 no crea la UDR de egreso."
  type        = string
  default     = null
}
