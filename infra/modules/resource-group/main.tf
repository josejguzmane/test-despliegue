variable "name" {
  description = "Nombre del resource group."
  type        = string
}

variable "location" {
  description = "Region de Azure."
  type        = string
}

variable "tags" {
  description = "Etiquetas."
  type        = map(string)
}

variable "lock_level" {
  description = "Nivel de management lock: null (sin lock), CanNotDelete o ReadOnly."
  type        = string
  default     = null

  validation {
    condition     = var.lock_level == null || contains(["CanNotDelete", "ReadOnly"], coalesce(var.lock_level, "CanNotDelete"))
    error_message = "lock_level debe ser null, CanNotDelete o ReadOnly."
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags

  lifecycle {
    # El resource group es el contenedor de la fase: un replace destruiria todo
    # lo que contiene. Se protege explicitamente.
    prevent_destroy = false # cambiar a true en prod tras el primer apply
  }
}

resource "azurerm_management_lock" "this" {
  count = var.lock_level == null ? 0 : 1

  name       = "lock-${var.name}"
  scope      = azurerm_resource_group.this.id
  lock_level = var.lock_level
  notes      = "Gestionado por Terraform. Quitar el lock solo via IaC."
}

output "id" {
  description = "ID del resource group."
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Nombre del resource group."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Region del resource group."
  value       = azurerm_resource_group.this.location
}
