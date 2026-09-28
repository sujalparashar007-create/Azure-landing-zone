# type = any on purpose: the resource group objects have different shapes
# (for example only one has an iam block), so a strict map type would fail.
variable "resource_groups" {
  description = "Flattened resource groups from yaml-processing (key = subscription/resource-group name)."
  type        = any
}

variable "subscriptions" {
  description = "Subscription name -> details (must contain subscription_id), from the management-groups module."
  type        = any
}