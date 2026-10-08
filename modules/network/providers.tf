# Provider requirements and configurations for the flat network module.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azapi" {
  # Disable the "ignore no-op changes" enhancement so adding networkSecurityGroup
  # to a subnet body (even when the remote already has it from a prior PATCH) is
  # detected as a change and persisted to the subnet's Terraform state.
  ignore_no_op_changes = false
}

provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
}
