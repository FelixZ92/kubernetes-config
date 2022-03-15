terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2022.3.1"
    }
  }
}

data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}

resource "authentik_group" "cluster_admins" {
  name = "cluster-admins"
  is_superuser = false
}

module "prometheus" {
  source = "./forward-auth-application"
  base_domain = var.BASE_DOMAIN
  auth_flow = data.authentik_flow.default-authorization-flow.id
  external_host = format("https://prometheus-authentik.%s/", var.BASE_DOMAIN)
  name = "prometheus"
  icon = "https://avatars1.githubusercontent.com/u/3380462?s=200&v=4"
  description = "https://prometheus.io/docs/prometheus/latest/"
  launch_url = format("https://prometheus-authentik.%s/graph/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group = authentik_group.cluster_admins.id
}

module "alertmanager" {
  source = "./forward-auth-application"
  base_domain = var.BASE_DOMAIN
  auth_flow = data.authentik_flow.default-authorization-flow.id
  external_host = format("https://alertmanager-authentik.%s/", var.BASE_DOMAIN)
  name = "alertmanager"
  icon = "https://avatars1.githubusercontent.com/u/3380462?s=200&v=4"
  description = "https://prometheus-authentik.io/docs/alerting/latest/alertmanager/"
  launch_url = format("https://alertmanager-authentik.%s/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group = authentik_group.cluster_admins.id
}

module "whoami" {
  source = "./forward-auth-application"
  base_domain = var.BASE_DOMAIN
  auth_flow = data.authentik_flow.default-authorization-flow.id
  external_host = format("https://whoami2.%s/", var.BASE_DOMAIN)
  name = "whoami"
  launch_url = format("https://whoami2.%s/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group = authentik_group.cluster_admins.id
}
