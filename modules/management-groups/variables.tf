variable "yaml_file" {
  description = "Optional path to the landing-zone YAML configuration. When null, uses yaml-processing/config/azure.yaml bundled alongside the yaml-processing module."
  type        = string
  default     = null
  nullable    = true
}
