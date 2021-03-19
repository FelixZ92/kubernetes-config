#!/usr/bin/env bash

SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets-controller
SEALED_SECRETS_CONTROLLER_NAMESPACE=kube-system

# $1: filename
# $2: outputDir
# $3: basedir
function encrypt_secret() {
    local filename="${1}"
    local outputDir="${2}"
    local basedir="${3}"
    kubeseal --controller-name "${SEALED_SECRETS_CONTROLLER_NAME}" \
      --controller-namespace "${SEALED_SECRETS_CONTROLLER_NAMESPACE}" \
      <"${basedir}/tmp/${filename}" \
      >"${outputDir}/${filename}"
}

# $1: namespace
# $2: name
# $3: username
# $4: password
# $5: filename
# $6: basedir
function create_generic_user_pass_secret() {
    local namespace="${1}"
    local name="${2}"
    local username="${3}"
    local password="${4}"
    local filename="${5}"
    local basedir="${6}"
    kubectl -n "${namespace}" --dry-run=client create secret generic "${name}" \
      --from-literal="username=${username}" --from-literal="password=${password}" -o json \
      > "${basedir}/tmp/${filename}"
}

# kudos to Sébastien Dubois (https://itnext.io/deploying-tls-certificates-for-local-development-and-production-using-kubernetes-cert-manager-9ab46abdd569)
# $1: basedir
update_local_ca_certs() {
  local basedir="${1}"
  if [ ! -f "${basedir}/.certs/dev/rootCA.pem" ] || [ ! -f "${basedir}/.certs/dev/rootCA-key.pem" ]; then
    rm -rf "${basedir}/.certs"
    mkdir -p "${basedir}/.certs/dev"
    mkdir -p "${basedir}/tmp"
    CAROOT=${basedir}/.certs/dev mkcert devmachine.local localhost -install
  fi

  kubectl -n cert-manager create secret tls dev-ca-secret \
    --key="${basedir}/.certs/dev/rootCA-key.pem" \
    --cert="${basedir}/.certs/dev/rootCA.pem" \
    --dry-run=client -o json \
    | kubeseal --controller-name "${SEALED_SECRETS_CONTROLLER_NAME}" \
        --controller-namespace "${SEALED_SECRETS_CONTROLLER_NAMESPACE}" \
        | kubectl apply -f -
}
