#!/usr/bin/env bash

set -eo pipefail

set -x

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"; exit 1
}

BASEDIR=$(dirname "$(dirname "$CURR_DIR")")

export KUBECONFIG="${HOME}/.kube/kubeconfig-rke2-staging.yaml"

BASE_DOMAIN="$(kubectl get cm -n kube-system cluster-env -o jsonpath='{.data.BASE_DOMAIN}')"
export BASE_DOMAIN
ENVIRONMENT="$(kubectl get cm -n kube-system cluster-env -o jsonpath='{.data.ENVIRONMENT}')"
export ENVIRONMENT

# shellcheck source=hack/secrets/secrets-common.sh
source "$CURR_DIR/../secrets/common.sh"
# shellcheck source=hack/common.sh
source "$CURR_DIR/../common.sh"

deploy_global_resources "${BASEDIR}"

deploy_flux "${BASEDIR}" "$HOME/.ssh/gitlab_deploy_key" "$BASEDIR/hack/known_hosts" "${ENVIRONMENT}"

kustomize build "$BASEDIR/system/sources" | kubectl apply -f -
kubectl apply -f "$BASEDIR/system/bootstrap.yaml"

kubectl wait --for=condition=ready --timeout=600s kustomizations.kustomize.toolkit.fluxcd.io -n kube-system bootstrap
apply_secrets "${BASEDIR}" "${ENVIRONMENT}"

#
#echo "Use with export KUBECONFIG=${KUBECONFIG}"
