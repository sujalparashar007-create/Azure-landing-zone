output "definition_ids" {
  description = "Map of custom policy definition key -> definition resource ID"
  value       = { for k, d in azurerm_policy_definition.this : k => d.id }
}

output "assignment_ids" {
  description = "Map of custom policy assignment name -> assignment resource ID"
  value       = { for k, a in azurerm_management_group_policy_assignment.this : k => a.id }
}