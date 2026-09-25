variable "management_groups" {
  description = "Flattened map of management group name -> management group record (from the yaml-processing module). Each record must carry its own 'name', 'display_name', and 'parent' (parent management group name, or \"tenant-root\" for top-level groups)."
  type        = any
}

variable "subscriptions" {
  description = "Flattened map of subscription name -> subscription record (from the yaml-processing module). Each record must carry 'display_name', 'billing_scope_id', and 'management_group' (the name of the management group it belongs to)."
  type        = any
}
