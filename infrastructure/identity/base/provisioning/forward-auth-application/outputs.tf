output "app_id" {
  value = authentik_application.app.uuid
}

output "provider_id" {
  value = authentik_provider_proxy.provider.id
}
