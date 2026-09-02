variable "alert_emails" {
  description = "Correos del grupo de accion de alertas. Guardia operativa."
  type        = list(string)
  default     = []
}

variable "enable_grafana" {
  description = "Crea Azure Managed Grafana. COSTO MEDIO (~50 USD/mes en Standard mas usuarios)."
  type        = bool
  default     = false
}

variable "enable_managed_prometheus" {
  description = "Crea el workspace de Azure Monitor para Prometheus. COSTO por muestras ingeridas."
  type        = bool
  default     = false
}

variable "slo_targets" {
  description = "Objetivos de nivel de servicio de la seccion 8. Se usan para generar las alertas de burn rate."
  type = map(object({
    objective   = number
    window_days = number
    description = string
  }))
  default = {}
}
