#!/usr/bin/env bash

if command -v gopass >/dev/null 2>&1; then
  PASSWORDSTORE_BINARY=gopass
elif command -v pass >/dev/null 2>&1; then
  PASSWORDSTORE_BINARY=pass
fi

SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets-controller
SEALED_SECRETS_CONTROLLER_NAMESPACE=kube-system

SCRIPT=$(readlink -f "$0")
# Absolute path this script is in
SCRIPTPATH=$(dirname "$SCRIPT")
BASE_DIR=$(dirname "$(dirname "$CURR_DIR")")

# $1: filename
# $2: outputDir
function encrypt_secret() {
    local filename="${1}"
    local outputDir="${2}"
    kubeseal --controller-name "${SEALED_SECRETS_CONTROLLER_NAME}" \
      --controller-namespace "${SEALED_SECRETS_CONTROLLER_NAMESPACE}" \
      <"${BASE_DIR}/tmp/${filename}" \
      >"${outputDir}/${filename}"
}

# $1: namespace
# $2: name
# $3: username
# $4: password
# $5: filename
function create_generic_user_pass_secret() {
    local namespace="${1}"
    local name="${2}"
    local username="${3}"
    local password="${4}"
    local filename="${5}"
    kubectl -n "${namespace}" --dry-run=client create secret generic "${name}" \
      --from-literal="username=${username}" --from-literal="password=${password}" -o json \
      > "${BASE_DIR}/tmp/${filename}"
}
