variable "app_fully_qualified_name" {
  description = "Fully qualified application name used in resource naming"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
}

variable "container_registry_login_server" {
  description = "Login server of the container registry"
  type        = string
}

variable "container_registry_id" {
  description = "ID of the container registry"
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the container app environment"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the key vault to write secrets to"
  type        = string
}

variable "app_name" {
  description = "Application name used as the container image name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "ingress_port" {
  description = "Port the container listens on for HTTP traffic"
  type        = number
  default     = 80
}
