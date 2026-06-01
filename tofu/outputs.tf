output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "Login server do ACR — valor do secret ACR_LOGIN_SERVER no GitHub."
}

output "acr_username" {
  value       = azurerm_container_registry.main.admin_username
  description = "Admin username do ACR."
}

output "acr_password" {
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
  description = "Admin password do ACR. Use: tofu output -raw acr_password"
}

output "api_url" {
  value       = "https://${azurerm_container_app.api_gateway.ingress[0].fqdn}"
  description = "URL pública da API Gateway."
}

output "deploy_webhook_url" {
  value       = "https://${azurerm_container_app.deploy_webhook.ingress[0].fqdn}"
  description = "URL do webhook de deploy automático."
}
