variable "organization_code" {
  description = "Organization code used in resource naming and to locate remote state"
  type        = string
}

variable "environment_group" {
  description = "Environment group name (e.g. nonprod, prod) — used to locate environment-group remote state"
  type        = string
}

variable "listeners" {
  description = "List of public listener URLs. Scheme determines protocol: https:// creates an HTTPS listener and looks up the certificate from the environment-group Key Vault using the hostname as the certificate name (e.g. https://comharte.com → cert name comharte-com). http:// creates an HTTP listener with no certificate."
  type        = list(string)
  default     = []
}

variable "nginx_config" {
  description = "Raw Nginx configuration file content. Injected as a Container App secret and mounted at /etc/nginx/nginx.conf."
  type        = string
  default     = ""
}
