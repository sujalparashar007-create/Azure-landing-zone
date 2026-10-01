module "yaml_processing" {
  source = "../yaml-processing"

  yaml_file = coalesce(var.yaml_file, "${path.module}/../yaml-processing/config/azure.yaml")
}

# Resolve each YAML subscription (keyed by name) to its live Azure
# subscription ID, matching only enabled subscriptions (disabled/deleted ones
# may linger with the same display name). `one()` makes the lookup
# deterministic and the check below fails clearly when a subscription cannot
# be resolved.
data "azurerm_subscriptions" "available" {}

locals {
  subscription_ids = {
    for name, sub in module.yaml_processing.subscriptions :
    name => one([
      for s in data.azurerm_subscriptions.available.subscriptions :
      s.id
      if s.display_name == sub.display_name && s.state == "Enabled"
    ])
  }
}

check "subscriptions_resolvable" {
  assert {
    condition = alltrue([
      for name, id in local.subscription_ids : id != null
    ])
    error_message = "Unable to resolve every YAML subscription to an Azure subscription by display name. Verify the subscriptions exist and their display names are unique."
  }
}

# Creates each subscription budget from the flattened YAML budget
# configuration. The YAML `currency` field is metadata only: Azure bills
# budgets in the subscription's native currency, and AzureRM exposes no
# currency argument.
resource "azurerm_consumption_budget_subscription" "this" {
  for_each = module.yaml_processing.budgets

  name            = each.value.budget_name
  subscription_id = local.subscription_ids[each.value.subscription]

  amount     = each.value.amount
  time_grain = each.value.time_grain

  time_period {
    start_date = each.value.start_date
  }

  dynamic "notification" {
    for_each = each.value.thresholds
    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThan"
      contact_emails = each.value.contact_emails
    }
  }
}
