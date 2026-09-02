data "terraform_remote_state" "foundation" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "00-foundation/${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "hub" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "10-network-hub/${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  foundation = data.terraform_remote_state.foundation.outputs
  hub        = data.terraform_remote_state.hub.outputs

  spoke_rg = local.foundation.resource_group_names["spoke"]
  hub_rg   = local.hub.resource_group_name
}
