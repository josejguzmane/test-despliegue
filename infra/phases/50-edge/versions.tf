terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend parcial: resource_group_name / storage_account_name /
  # container_name / key se inyectan con -backend-config desde CI o
  # scripts/tf.sh. El bloqueo de state lo da el lease del blob, nativo.
  backend "azurerm" {}
}
