output "management_group_ids" {
  description = "Map of management group name -> management group resource ID. Used by sibling modules (e.g. rbac, policy, resource-groups) that need to reference these management groups by name."
  value       = local.management_group_ids_by_name
}

output "subscriptions" {
  description = "Map of subscription name -> subscription details (id, display name, and the management group it's associated with)."
  value = {
    for key, sub in azurerm_subscription.this : key => {
      subscription_id      = sub.subscription_id
      subscription_name    = sub.subscription_name
      management_group_id  = local.subscriptions[key].management_group_id
    }
  }
}
