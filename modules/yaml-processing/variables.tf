variable "yaml_file" {
  description = "Path to the Landing Zone YAML configuration"
  type        = string
  default     = "config/azure.yaml"
}

variable "network_yaml_file" {
  description = "Path to the network YAML configuration"
  type        = string
  default     = "config/network.yaml"
}