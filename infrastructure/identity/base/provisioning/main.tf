#provider "pass" {
#  store_dir = "~/.local/share/gopass/stores/kubernetes"
#  refresh_store = false
#}

data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}

resource "authentik_group" "cluster_admins" {
  name         = "cluster-admins"
  is_superuser = false
}

resource "authentik_group" "grafana_admins" {
  name         = "Grafana Admins"
  is_superuser = false
}

resource "authentik_group" "grafana_editors" {
  name         = "Grafana Editors"
  is_superuser = false
}

module "prometheus" {
  source         = "./forward-auth-application"
  base_domain    = var.BASE_DOMAIN
  auth_flow      = data.authentik_flow.default-authorization-flow.id
  external_host  = format("https://prometheus.%s/", var.BASE_DOMAIN)
  name           = "prometheus"
  icon           = "https://avatars1.githubusercontent.com/u/3380462?s=200&v=4"
  description    = "https://prometheus.io/docs/prometheus/latest/"
  launch_url     = format("https://prometheus.%s/graph/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group          = authentik_group.cluster_admins.id
}

module "alertmanager" {
  source         = "./forward-auth-application"
  base_domain    = var.BASE_DOMAIN
  auth_flow      = data.authentik_flow.default-authorization-flow.id
  external_host  = format("https://alertmanager.%s/", var.BASE_DOMAIN)
  name           = "alertmanager"
  icon           = "https://avatars1.githubusercontent.com/u/3380462?s=200&v=4"
  description    = "https://prometheus.io/docs/alerting/latest/alertmanager/"
  launch_url     = format("https://alertmanager.%s/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group          = authentik_group.cluster_admins.id
}

module "postgres" {
  source         = "./forward-auth-application"
  base_domain    = var.BASE_DOMAIN
  auth_flow      = data.authentik_flow.default-authorization-flow.id
  external_host  = format("https://postgres.%s/", var.BASE_DOMAIN)
  name           = "postgres"
  icon           = "https://github.com/zalando/postgres-operator/blob/master/docs/diagrams/logo.png?raw=true"
  description    = "https://postgres-operator.readthedocs.io/en/latest/"
  launch_url     = format("https://postgres.%s/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group          = authentik_group.cluster_admins.id
}

module "traefik" {
  source         = "./forward-auth-application"
  base_domain    = var.BASE_DOMAIN
  auth_flow      = data.authentik_flow.default-authorization-flow.id
  external_host  = format("https://traefik.%s/dashboard/", var.BASE_DOMAIN)
  name           = "traefik"
  icon           = "https://github.com/traefik/traefik/blob/master/docs/content/assets/img/traefik.logo.png?raw=true"
  description    = "https://docs.traefik.io/"
  launch_url     = format("https://traefik.%s/dashboard/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group          = authentik_group.cluster_admins.id
}

module "whoami" {
  source         = "./forward-auth-application"
  base_domain    = var.BASE_DOMAIN
  auth_flow      = data.authentik_flow.default-authorization-flow.id
  external_host  = format("https://whoami2.%s/", var.BASE_DOMAIN)
  name           = "whoami"
  launch_url     = format("https://whoami2.%s/", var.BASE_DOMAIN)
  k8s_connection = authentik_service_connection_kubernetes.local.id
  group          = authentik_group.cluster_admins.id
}

data "pass_password" "grafana_client_secret" {
  path = format("kubernetes/%s/authentik/grafana/client-secret", var.ENVIRONMENT)
}

data "authentik_scope_mapping" "test" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

resource "authentik_provider_oauth2" "grafana" {
  name               = "grafana"
  client_id          = "grafana"
  client_secret      = data.pass_password.grafana_client_secret.password
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  property_mappings  = data.authentik_scope_mapping.test.ids
  redirect_uris      = [format("https://grafana.%s/login/generic_oauth", var.BASE_DOMAIN)]
}

resource "authentik_application" "grafana" {
  name              = "grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
  meta_icon         = "https://cdn.worldvectorlogo.com/logos/grafana.svg"
  meta_description  = "https://grafana.com/docs/grafana/latest/"
  meta_launch_url   = format("https://grafana.%s/", var.BASE_DOMAIN)
}

resource "authentik_provider_oauth2" "ocis" {
  name               = "ocis-web"
  client_id          = "ocis-web"
  client_type        = "public"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  property_mappings  = data.authentik_scope_mapping.test.ids
  redirect_uris      = [format("https://ocis.%s/", var.BASE_DOMAIN)]
}

resource "authentik_application" "ocis" {
  name              = "ocis-web"
  slug              = "ocis-web"
  protocol_provider = authentik_provider_oauth2.ocis.id
  meta_icon         = "https://owncloud.dev/logo.png"
  meta_description  = "https://owncloud.dev/"
  meta_launch_url   = format("https://ocis.%s/", var.BASE_DOMAIN)
}

data "authentik_property_mapping_saml" "nextcloud" {
  managed_list = [
    "goauthentik.io/providers/saml/uid",
    "goauthentik.io/providers/saml/username",
    "goauthentik.io/providers/saml/ms-windowsaccountname",
    "goauthentik.io/providers/saml/groups",
    "goauthentik.io/providers/saml/email",
    "goauthentik.io/providers/saml/name",
    "goauthentik.io/providers/saml/upn"
  ]
}

resource "authentik_provider_saml" "nextcloud" {
  name               = "nextcloud"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  acs_url            = format("https://nextcloud.%s/apps/user_saml/saml/acs", var.BASE_DOMAIN)
  issuer             = format("https://authentik.%s", var.BASE_DOMAIN)
  sp_binding         = "post"
  audience           = format("https://nextcloud.%s/apps/user_saml/saml/metadata", var.BASE_DOMAIN)
  property_mappings  = data.authentik_property_mapping_saml.nextcloud.ids
}

resource "authentik_application" "nextcloud" {
  name              = "nextcloud"
  slug              = "nextcloud"
  protocol_provider = authentik_provider_saml.nextcloud.id
}

