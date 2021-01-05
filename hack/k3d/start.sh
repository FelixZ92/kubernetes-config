#!/usr/bin/env bash

set -o pipefail

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"; exit 1
}

BASEDIR=$(dirname "$(dirname "$CURR_DIR")")

echo $BASEDIR

# shellcheck source=hack/secrets/secrets-common.sh
source "$CURR_DIR/../secrets/common.sh"
# shellcheck source=hack/common.sh
source "$CURR_DIR/../common.sh"

k3d cluster create local \
  --k3s-server-arg '--kube-apiserver-arg=enable-admission-plugins=PodSecurityPolicy' \
  -v "${CURR_DIR}/psp.yaml:/var/lib/rancher/k3s/server/manifests/psp.yaml" \
  --agents 3 \
  --k3s-server-arg '--disable=traefik' \
  --k3s-server-arg '--disable=servicelb'

sleep 10

export KUBECONFIG=$(k3d kubeconfig write local)

deploy_global_resources "${BASEDIR}"

deploy_sealed_secrets "${BASEDIR}"

deploy_flux "${BASEDIR}" "$HOME/.ssh/gitlab_deploy_key" "$BASEDIR/hack/known_hosts" "dev"

update_local_ca_certs "${BASEDIR}"

kubectl create namespace cert-manager
kustomize build "$BASEDIR/02_bootstrap/dev" | kubectl apply -f -

deploy_prometheus_operator_crds
#
#echo "Use with export KUBECONFIG=${KUBECONFIG}"
