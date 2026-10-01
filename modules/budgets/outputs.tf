output "budget_ids" {
  description = "Map of budget key -> Azure subscription budget resource ID"
  value       = { for key, budget in azurerm_consumption_budget_subscription.this : key => budget.id }
}
