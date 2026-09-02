# La suscripcion y las credenciales llegan por entorno:
#   ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_USE_OIDC=true
# No hay secretos de service principal en ninguna parte (seccion 9 del diseno).
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = false
    }
  }

  storage_use_azuread             = true
  resource_provider_registrations = "none"
}
