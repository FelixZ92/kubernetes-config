#!/usr/bin/env bash

set -o pipefail

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"; exit 1
}

BASEDIR=$(dirname "$(dirname "$CURR_DIR")")

ENVIRONMENT=dev

# shellcheck source=hack/secrets/secrets-common.sh
source "$CURR_DIR/../secrets/common.sh"
# shellcheck source=hack/common.sh
source "$CURR_DIR/../common.sh"

k3d cluster create local \
  --k3s-server-arg '--kube-apiserver-arg=enable-admission-plugins=PodSecurityPolicy' \
  -v "${CURR_DIR}/psp.yaml:/var/lib/rancher/k3s/server/manifests/psp.yaml" \
  --agents 3 \
  --k3s-server-arg '--disable=traefik' \
  --k3s-server-arg '--disable=servicelb' \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer"


sleep 10

export KUBECONFIG=$(k3d kubeconfig write local)
kubectl label node k3d-local-agent-0 storage=local
kubectl label node k3d-local-agent-1 storage=local
kubectl label node k3d-local-agent-2 storage=local
kubectl label node k3d-local-agent-2 node.kubernetes.io/ingress=traefik

deploy_global_resources "${BASEDIR}"

deploy_sealed_secrets "${BASEDIR}"

apply_secrets "${BASEDIR}" "${ENVIRONMENT}"

update_local_ca_certs "${BASEDIR}"

deploy_flux "${BASEDIR}" "$HOME/.ssh/gitlab_deploy_key" "$BASEDIR/hack/known_hosts" "${ENVIRONMENT}"

deploy_prometheus_operator_crds "${BASEDIR}"

kubectl create namespace cert-manager

kustomize build "$BASEDIR/02_bootstrap/${ENVIRONMENT}" | kubectl apply -f -

#
#echo "Use with export KUBECONFIG=${KUBECONFIG}"
