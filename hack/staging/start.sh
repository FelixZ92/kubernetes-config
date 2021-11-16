#!/usr/bin/env bash

set -eo pipefail

set -x

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"; exit 1
}

BASEDIR=$(dirname "$(dirname "$CURR_DIR")")

export BASE_DOMAIN=162.55.159.246.nip.io
export ENVIRONMENT=staging

# shellcheck source=hack/secrets/secrets-common.sh
source "$CURR_DIR/../secrets/common.sh"
# shellcheck source=hack/common.sh
source "$CURR_DIR/../common.sh"

export KUBECONFIG="${HOME}/.kube/kubeconfig-rke2-staging.yaml"

deploy_global_resources "${BASEDIR}"

deploy_flux "${BASEDIR}" "$HOME/.ssh/gitlab_deploy_key" "$BASEDIR/hack/known_hosts" "${ENVIRONMENT}"

kustomize build "$BASEDIR/01_gitops/bootstrap/overlays/${ENVIRONMENT}/" | envsubst | kubectl apply -f -

kubectl wait --for=condition=ready --timeout=600s kustomizations.kustomize.toolkit.fluxcd.io -n flux-system bootstrap
kubectl wait --for=condition=ready --timeout=600s kustomizations.kustomize.toolkit.fluxcd.io -n flux-system sealed-secrets
apply_secrets "${BASEDIR}" "${ENVIRONMENT}"

#
#echo "Use with export KUBECONFIG=${KUBECONFIG}"
