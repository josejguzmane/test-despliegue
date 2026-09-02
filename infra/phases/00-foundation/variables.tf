variable "log_retention_days" {
  description = "Retencion en dias del workspace de Log Analytics. El diseno pide 2 anos de auditoria, pero eso se cubre con archivado inmutable en Storage (fase 70), no con retencion cara en LAW."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days debe estar entre 30 y 730."
  }
}

variable "log_daily_quota_gb" {
  description = "Tope diario de ingesta en GB. -1 = sin tope. Los logs son el segundo costo mayor (seccion 12); en no productivos conviene acotarlos."
  type        = number
  default     = -1
}

variable "resource_group_lock_level" {
  description = "Lock aplicado a los resource groups. null en dev, CanNotDelete en prod."
  type        = string
  default     = null
}
