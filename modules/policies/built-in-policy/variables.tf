variable "policies" {
  description = "Flat map of built-in policy assignments, keyed by scope_name-name (from yaml-processing's builtin_policies output)"
  type        = any
}

variable "scope_ids" {
  description = "Map of scope_name (tenant-root or a management group's name) -> Azure resource ID"
  type        = map(string)
}