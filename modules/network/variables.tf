# Shared inputs for YAML configuration and Azure API retry behavior.
variable "yaml_file" {
  description = "Optional path to the landing-zone YAML configuration. When null, uses yaml-processing/config/azure.yaml."
  type        = string
  default     = null
  nullable    = true
}

variable "network_yaml_file" {
  description = "Optional path to the network YAML configuration. When null, uses yaml-processing/config/network.yaml."
  type        = string
  default     = null
  nullable    = true
}

variable "azapi_retry" {
  description = "Retry settings for transient Azure API errors."
  type = object({
    error_message_regex  = list(string)
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default = {
    error_message_regex  = ["AnotherOperationInProgress", "RetryableError", "ReferencedResourceNotProvisioned"]
    interval_seconds     = 10
    max_interval_seconds = 120
  }
}
