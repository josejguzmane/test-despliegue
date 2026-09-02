variable "prefix" {
  description = "Prefijo de la plataforma (ej. itsm)."
  type        = string
}

variable "environment" {
  description = "Entorno logico: dev | qa | prod."
  type        = string
}

variable "location" {
  description = "Region de Azure (nombre corto de API, ej. eastus2)."
  type        = string
}

variable "component" {
  description = "Componente o fase (ej. hub, spoke, data, aks, edge, obs, sec)."
  type        = string
}

variable "cost_center" {
  description = "Centro de costo, etiqueta obligatoria."
  type        = string
}

variable "owner" {
  description = "Responsable operativo."
  type        = string
}

variable "phase" {
  description = "Nombre de la fase de despliegue que crea el recurso (ej. 10-network-hub)."
  type        = string
}

variable "extra_tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
