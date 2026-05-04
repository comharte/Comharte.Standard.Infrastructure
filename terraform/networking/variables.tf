variable "organization_code" {
  description = "Organization code used in resource naming and to locate remote state"
  type        = string
}

variable "apps" {
  description = "List of apps to configure AGW routing for. Each app has a public hostname and a map of URL path prefixes to backend FQDNs. Use '*' as the key for the default (catch-all) backend."
  type = list(object({
    public_url = string
    routings   = map(string)
  }))
  default = []
}
