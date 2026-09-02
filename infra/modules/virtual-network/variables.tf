variable "name" {
  description = "Nombre de la VNet."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group destino."
  type        = string
}

variable "location" {
  description = "Region de Azure."
  type        = string
}

variable "address_space" {
  description = "Lista de CIDR de la VNet."
  type        = list(string)
}

variable "dns_servers" {
  description = "DNS custom de la VNet. Vacio = DNS de Azure. En los spokes apunta al inbound endpoint del DNS Private Resolver del hub."
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = <<-EOT
    Mapa de subredes. La clave es el nombre logico; para subredes con nombre
    obligatorio de Azure (AzureFirewallSubnet, AzureBastionSubnet, GatewaySubnet)
    usar exactamente ese nombre como clave.

    - address_prefixes            : CIDR de la subred
    - private_endpoint_policies   : "Disabled" en la subred de private endpoints
    - service_endpoints           : lista de service endpoints
    - delegation                  : { name, service, actions } o null
    - associate_nsg               : crea y asocia un NSG dedicado (no aplica a
                                    AzureFirewallSubnet ni GatewaySubnet)
    - associate_route_table       : asocia la route table pasada en route_table_id
  EOT
  type = map(object({
    address_prefixes          = list(string)
    private_endpoint_policies = optional(string, "Enabled")
    service_endpoints         = optional(list(string), [])
    delegation = optional(object({
      name    = string
      service = string
      actions = list(string)
    }))
    associate_nsg         = optional(bool, true)
    associate_route_table = optional(bool, false)
  }))
}

variable "route_table_id" {
  description = "ID de la route table a asociar en las subredes con associate_route_table = true."
  type        = string
  default     = null
}

variable "tags" {
  description = "Etiquetas."
  type        = map(string)
}
