#!/usr/bin/env bash

# $1: environment: dev, stg, prod
# $2 root-domain: 192.168.0.13.xip.io, stg.zippelf.com, zippelf.com
#
#

set -eou pipefail

if [ -z "$1" ]; then
  echo "No environment supplied, exit"
  exit 1
else
  K8S_ENVRIONMENT="$1"
fi

if [ -z "$2" ]; then
  echo "No root domain supplied, exit"
  exit 1
else
  export ROOT_DOMAIN="$2"
fi

# shellcheck source=hack/secrets-common.sh
source "$SCRIPTPATH/secrets-common.sh"

PASSWORDSTORE_BASE_DIR="clusters/${K8S_ENVRIONMENT}"

export OIDC_CLIENT_ID=k8s

OIDC_NAMESPACES="monitoring traefik postgres-operator argocd keycloak longhorn-system dashboard"

# $1: namespace
function create_oidc_secret() {
    local namespace="${1}"
    kubectl -n "${namespace}" --dry-run=client create secret generic oidc-secret \
      --from-literal=clientid="${OIDC_CLIENT_ID}" --from-literal=secret="${OIDC_SECRET}" -o json \
      >"${BASE_DIR}/tmp/${namespace}-oidc-secret.json"
    encrypt_secret "${namespace}-oidc-secret.json" "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets"
    git add "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets/${namespace}-oidc-secret.json"
}

function create_oidc_secrets() {
    if ! OIDC_SECRET=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/oidc/secret"); then
        echo "${PASSWORDSTORE_BASE_DIR}/oidc/secret not found, exit"
    fi
    for n in ${OIDC_NAMESPACES}; do
        echo "${n}"
        create_oidc_secret "${n}"
    done
    git commit -m "Re-encrypt oidc secrets"
    git push
}

# $1: namespace
function create_signing_secret() {
    local namespace="${1}"
    openssl rand -hex 16 | tr -d '\n' > "${BASE_DIR}/tmp/${namespace}-oidc-signing-secret.tmp"
    kubectl -n "${namespace}" --dry-run=client create secret generic oidc-signing-secret \
      --from-file=secret="${BASE_DIR}/tmp/${namespace}-oidc-signing-secret.tmp" -o json \
      > "${BASE_DIR}/tmp/${namespace}-oidc-signing-secret.json"
    encrypt_secret "${namespace}-oidc-signing-secret.json" "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets"
    git add "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets/${namespace}-oidc-signing-secret.json"
}

function create_signing_secrets() {
    for n in ${OIDC_NAMESPACES}; do
        echo "${n}"
        create_signing_secret "${n}"
    done
    git commit -m "Re-encrypt signing secrets"
    git push
}

function create_keycloak_secret() {
    if ! KEYCLOAK_PASSWORD=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/keycloak/admin"); then
        echo "Generating password ${PASSWORDSTORE_BASE_DIR}/keycloak/admin"
        ${PASSWORDSTORE_BINARY} generate "${PASSWORDSTORE_BASE_DIR}/keycloak/admin"
        KEYCLOAK_PASSWORD=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/keycloak/admin")
    fi
    create_generic_user_pass_secret "keycloak" "keycloak-admin-user" "keycloak" "${KEYCLOAK_PASSWORD}" "keycloak-admin-user.json"
    encrypt_secret "keycloak-admin-user.json" "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets/"
    git add "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets/keycloak-admin-user.json"
    git commit -m "Re-encrypt keycloak secret"
		git push
}

function create_grafana_secret() {
    if ! GRAFANA_PASSWORD=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/keycloak/admin"); then
        echo "Generating password ${PASSWORDSTORE_BASE_DIR}/keycloak/admin"
        ${PASSWORDSTORE_BINARY} generate "${PASSWORDSTORE_BASE_DIR}/keycloak/admin"
        GRAFANA_PASSWORD=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/keycloak/admin")
    fi
    create_generic_user_pass_secret "monitoring" "grafana-admin-user" "admin" "${GRAFANA_PASSWORD}" "grafana-admin-user.json"
    encrypt_secret "grafana-admin-user.json" "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets/"
    git add "${BASE_DIR}/03_infrastructure/argocd-apps/${K8S_ENVRIONMENT}/secrets/grafana-admin-user.json"
    git commit -m "Re-encrypt grafana secret"
		git push
}

function create_grafana_generic_auth_secret() {
    if [ "${K8S_ENVRIONMENT}" = "dev" ]; then
        export SKIP_TLS=true
    else
        export SKIP_TLS=false
    fi
    export OIDC_SECRET
    envsubst '${ROOT_DOMAIN} ${OIDC_CLIENT_ID} ${OIDC_SECRET} ${SKIP_TLS}' \
      < hack/grafana-generic-auth-secret.yaml \
      > tmp/grafana-generic-auth-secret.yaml
		encrypt_secret "grafana-generic-auth-secret.yaml" "${BASE_DIR}/03_infrastructure/observability/prometheus-operator/${K8S_ENVRIONMENT}"
    git add "${BASE_DIR}/03_infrastructure/observability/prometheus-operator/${K8S_ENVRIONMENT}"
    git commit -m "Re-encrypt grafana-generic-auth secret"
		git push
}

function create_owncloud_admin_secret() {
    if ! OWNCLOUD_PASSWORD=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/owncloud/admin"); then
        echo "Generating password ${PASSWORDSTORE_BASE_DIR}/owncloud/admin"
        ${PASSWORDSTORE_BINARY} generate "${PASSWORDSTORE_BASE_DIR}/owncloud/admin"
        OWNCLOUD_PASSWORD=$(${PASSWORDSTORE_BINARY} "${PASSWORDSTORE_BASE_DIR}/owncloud/admin")
    fi
    kubectl -n "owncloud" --dry-run=client create secret generic "owncloud-config" \
      --from-literal="OWNCLOUD_ADMIN_PASSWORD=${OWNCLOUD_PASSWORD}" -o json \
      > "${BASE_DIR}/tmp/owncloud-admin-user.json"

    encrypt_secret "owncloud-admin-user.json" "${BASE_DIR}/04_services/owncloud/${K8S_ENVRIONMENT}/"
    git add "${BASE_DIR}/04_services/owncloud/${K8S_ENVRIONMENT}/owncloud-admin-user.json"
    git commit -m "Re-encrypt owncloud secret"
		git push
}

create_oidc_secrets
create_signing_secrets
create_keycloak_secret
create_grafana_secret
create_grafana_generic_auth_secret
