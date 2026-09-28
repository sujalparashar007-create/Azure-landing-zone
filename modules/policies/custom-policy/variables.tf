variable "policies" {
  description = "Flat map of custom policy assignments, keyed by scope_name-name (from yaml-processing's custom_policies output)"
  type        = any
}

variable "scope_ids" {
  description = "Map of scope_name (tenant-root or a management group's name) -> Azure resource ID"
  type        = map(string)
}

variable "definitions_management_group_id" {
  description = "Management group ID where custom policy DEFINITIONS get created (tenant root, so they're visible to all child scopes)"
  type        = string
}