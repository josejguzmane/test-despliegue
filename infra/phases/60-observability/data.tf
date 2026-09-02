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

locals {
  foundation = data.terraform_remote_state.foundation.outputs

  obs_rg = local.foundation.resource_group_names["obs"]
  law_id = local.foundation.log_analytics_workspace_id
}
