variable "private_dns_zones" {
  description = "Zonas DNS privadas de los private endpoints (seccion 3.6). Se crean en el resource group del hub y se ligan a hub y spoke."
  type        = list(string)
}

variable "enable_postgresql" {
  description = "Crea PostgreSQL Flexible Server. COSTO ALTO (HA zona-redundante desde ~350 USD/mes)."
  type        = bool
  default     = false
}

variable "enable_redis" {
  description = "Crea Azure Cache for Redis Premium. COSTO ALTO (~400 USD/mes en P1 zona-redundante)."
  type        = bool
  default     = false
}

variable "enable_service_bus" {
  description = "Crea Service Bus Premium. COSTO ALTO (~670 USD/mes por unidad de mensajeria)."
  type        = bool
  default     = false
}

variable "enable_storage" {
  description = "Crea la storage account de adjuntos. COSTO BAJO, por uso."
  type        = bool
  default     = false
}

variable "enable_key_vault" {
  description = "Crea Key Vault Premium. COSTO BAJO."
  type        = bool
  default     = false
}

variable "enable_acr" {
  description = "Crea Azure Container Registry Premium. COSTO MEDIO (~50 USD/mes mas replicacion geografica)."
  type        = bool
  default     = false
}

variable "enable_ai_search" {
  description = "Crea Azure AI Search. COSTO MEDIO (~250 USD/mes en Standard S1)."
  type        = bool
  default     = false
}
