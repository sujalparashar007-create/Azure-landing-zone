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
