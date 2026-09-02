variable "public_hostname" {
  description = "Nombre publico del portal, ej. portal.contoso.com. Solo informativo mientras el borde no este implementado."
  type        = string
  default     = ""
}

variable "enable_front_door" {
  description = "Crea Front Door Premium con WAF. COSTO ALTO (~330 USD/mes de base mas trafico y reglas)."
  type        = bool
  default     = false
}

variable "enable_apim" {
  description = "Crea API Management en modo interno. COSTO ALTO (~2800 USD/mes en Premium; Developer ~50 USD/mes sin SLA)."
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "Modo de la politica WAF: Detection para rodaje, Prevention en produccion."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode debe ser Detection o Prevention."
  }
}

variable "rate_limit_rules" {
  description = "Limites por IP del WAF (seccion 3.3). Clave = nombre de la regla."
  type = map(object({
    path_prefix = string
    limit       = number
    window_min  = number
  }))
  default = {}
}
