output "assignment_ids" {
  description = "Map of built-in policy assignment name -> assignment resource ID"
  value = {
    for k, a in azurerm_management_group_policy_assignment.this : k => a.id
  }
}