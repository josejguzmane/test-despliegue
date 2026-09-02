# ---------------------------------------------------------------------------
# ARCHIVO GENERADO - NO EDITAR EN LA FASE.
# Fuente: infra/shared/variables.common.tf
# Regenerar con: make sync-common   (o ./scripts/sync-common.sh)
# CI falla si una copia queda desincronizada.
# ---------------------------------------------------------------------------

variable "prefix" {
  description = "Prefijo corto de la plataforma. Se usa en todos los nombres de recurso."
  type        = string
  default     = "itsm"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.prefix))
    error_message = "prefix debe ser minusculas/digitos, 2-8 caracteres, empezando por letra."
  }
}

variable "environment" {
  description = "Entorno logico: dev | qa | prod."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment debe ser dev, qa o prod."
  }
}

variable "location" {
  description = "Region primaria de Azure."
  type        = string
  default     = "eastus2"
}

variable "cost_center" {
  description = "Centro de costo. Obligatorio: Azure Policy deniega recursos sin esta etiqueta (seccion 4.4 del diseno)."
  type        = string
}

variable "owner" {
  description = "Equipo o persona responsable operativa del recurso."
  type        = string
}

variable "extra_tags" {
  description = "Etiquetas adicionales que se fusionan sobre las estandar."
  type        = map(string)
  default     = {}
}

# --- Backend remoto (se inyecta desde CI, no se versiona el valor real) ------

variable "tfstate_resource_group_name" {
  description = "Resource group de la storage account del state remoto."
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account del state remoto."
  type        = string
}

variable "tfstate_container_name" {
  description = "Contenedor de blobs del state remoto."
  type        = string
  default     = "tfstate"
}
