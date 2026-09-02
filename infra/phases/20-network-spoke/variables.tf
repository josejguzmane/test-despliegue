variable "spoke_address_space" {
  description = "CIDR de la VNet spoke de aplicacion. Diseno: 10.10.0.0/16."
  type        = list(string)
}

variable "spoke_subnets" {
  description = "Subredes del spoke, por clave logica."
  type        = map(string)
}

variable "enable_peering" {
  description = "Crea el peering bidireccional hub-spoke. Requiere que la fase 10 haya corrido."
  type        = bool
  default     = true
}

variable "use_remote_gateways" {
  description = "El spoke usa el VPN/ER gateway del hub. Solo puede ser true cuando el gateway existe, si no el peering falla."
  type        = bool
  default     = false
}
