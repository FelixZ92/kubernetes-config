#!/usr/bin/env bash

# kudos to Sébastien Dubois (https://itnext.io/deploying-tls-certificates-for-local-development-and-production-using-kubernetes-cert-manager-9ab46abdd569)

set -eou pipefail

SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
BASE_DIR=$SCRIPTPATH/..

SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets-controller
SEALED_SECRETS_CONTROLLER_NAMESPACE=kube-system

if [ ! -f "${BASE_DIR}/.certs/dev/rootCA.pem" ] || [ ! -f "${BASE_DIR}/.certs/dev/rootCA-key.pem" ]; then
  @rm -rf "${BASE_DIR}/.certs"
  mkdir -p "${BASE_DIR}/.certs/dev"
  mkdir -p "${BASE_DIR}/tmp"
  CAROOT=${BASE_DIR}/.certs/dev mkcert -install
fi

kubectl -n cert-manager create secret tls dev-ca-secret \
  --key="${BASE_DIR}/.certs/dev/rootCA-key.pem" \
  --cert="${BASE_DIR}/.certs/dev/rootCA.pem" \
  --dry-run=client -o json \
  > "${BASE_DIR}/tmp/dev-ca-secret.json"

kubeseal --controller-name "${SEALED_SECRETS_CONTROLLER_NAME}" \
  --controller-namespace "${SEALED_SECRETS_CONTROLLER_NAMESPACE}" \
  <"${BASE_DIR}/tmp/dev-ca-secret.json" \
  >"${BASE_DIR}/03_infrastructure/cert-manager/dev/dev-ca-secret-sealed.json"

git add "${BASE_DIR}/03_infrastructure/cert-manager/dev/dev-ca-secret-sealed.json"
git commit -m "Update dev CA"
git push
