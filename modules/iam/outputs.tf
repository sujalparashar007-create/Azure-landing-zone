output "assignment_ids" {
  description = "Map of IAM assignment keys to Azure role assignment IDs."
  value       = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}