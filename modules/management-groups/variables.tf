variable "config" {
  description = "Decoded YAML configuration object (output of yamldecode), passed in from the root module so the YAML file is only read once."
  type        = any
}
