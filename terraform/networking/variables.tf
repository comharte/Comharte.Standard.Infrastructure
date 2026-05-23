variable "organization_code" {
  description = "Organization code used in resource naming and to locate remote state"
  type        = string
}

variable "apps" {
  description = "List of apps to configure AGW routing for. Each app has a public hostname, a map of URL path prefixes to backend FQDNs, and an optional SSL certificate name for HTTPS termination. Use '*' as the key for the default (catch-all) backend."
  type = list(object({
    public_url           = string
    routings             = map(string)
    ssl_certificate_name = optional(string)
  }))
  default = []
}

variable "ssl_certificates" {
  description = "Map of certificate name to base64-encoded PFX data and password. Sensitive — injected at deploy time by the pipeline."
  type = map(object({
    data     = string
    password = string
  }))
  default   = {}
  sensitive = true
}
