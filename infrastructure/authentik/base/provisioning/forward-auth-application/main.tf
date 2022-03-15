resource "authentik_provider_proxy" "provider" {
  name               = var.name
  external_host      = var.external_host
  authorization_flow = var.auth_flow
  token_validity     = "hours=24"
  mode               = "forward_single"
}

resource "authentik_application" "app" {
  name              = var.name
  slug              = var.name
  protocol_provider = authentik_provider_proxy.provider.id
  meta_icon         = var.icon
  meta_description  = var.description
  meta_publisher    = var.publisher
  meta_launch_url   = var.launch_url
}

resource "authentik_policy_binding" "app-access" {
  target  = authentik_application.app.uuid
  group   = var.group
  enabled = true
  order   = 0
  timeout = 30
}

resource "authentik_outpost" "outpost" {
  name               = var.name
  protocol_providers = [
    authentik_provider_proxy.provider.id,
  ]
  config = jsonencode({
    authentik_host                 = format("http://authentik/")
    authentik_host_insecure        = true
    authentik_host_browser         = format("https://authentik.%s/", var.base_domain)
    log_level                      = "info"
    object_naming_template         = "ak-outpost-%(name)s"
    kubernetes_replicas            = 1
    kubernetes_namespace           = "authentik"
    kubernetes_service_type        = "ClusterIP"
    kubernetes_disabled_components = ["ingress"]
  })
  service_connection = var.k8s_connection
}
