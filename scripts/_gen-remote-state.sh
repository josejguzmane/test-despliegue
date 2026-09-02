#!/usr/bin/env bash
# Genera un bloque terraform_remote_state para la fase indicada.
set -euo pipefail
name="$1"; key="$2"
cat <<BLOCK
data "terraform_remote_state" "${name}" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "${key}/\${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

BLOCK
