variable "assignments" {
  description = "Flattened IAM assignments keyed by scope, role, and principal."
  type        = any
}

variable "scope_ids" {
  description = "Map of logical IAM scope names to Azure resource IDs."
  type        = map(string)
}
