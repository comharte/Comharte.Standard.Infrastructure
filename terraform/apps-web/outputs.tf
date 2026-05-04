output "url" {
  value = var.with_hosting ? module.hosting[0].url : null
}
