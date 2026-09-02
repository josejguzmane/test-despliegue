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

data "terraform_remote_state" "spoke" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "20-network-spoke/${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "data" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "30-data/${var.environment}.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  foundation = data.terraform_remote_state.foundation.outputs
  spoke      = data.terraform_remote_state.spoke.outputs
  data_layer = data.terraform_remote_state.data.outputs

  edge_rg = local.foundation.resource_group_names["edge"]
}
