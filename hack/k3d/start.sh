#!/usr/bin/env bash

set -o pipefail

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"
  exit 1
}

# shellcheck source=hack/secrets-common.sh
source "$CURR_DIR/../hack/secrets-common.sh"

k3d cluster create local \
  --k3s-server-arg '--kube-apiserver-arg=enable-admission-plugins=PodSecurityPolicy' \
  -v "${CURR_DIR}/psp.yaml:/var/lib/rancher/k3s/server/manifests/psp.yaml" \
  --agents 3 \
  --k3s-server-arg '--disable=traefik' \
  --k3s-server-arg '--disable=servicelb'

sleep 20

export KUBECONFIG=$(k3d kubeconfig write local)

kustomize build "$CURR_DIR/../00_global-resources" \
  | kubectl apply -f -
kustomize build "$CURR_DIR/../03_infrastructure/pki/sealed-secrets/base/" \
  | kubectl apply -f -

kubectl wait --for=condition=available --timeout=600s deployment/sealed-secrets-controller -n kube-system

kubectl create ns flux-system
kubectl --dry-run=client \
  --namespace flux-system \
  create secret generic flux-system \
  --from-file="identity.pub=$HOME/.ssh/gitlab_deploy_key.pub" \
  --from-file="identity=$HOME/.ssh/gitlab_deploy_key" \
  --from-file="known_hosts=$CURR_DIR/../hack/known_hosts" \
  -o json \
   >"${CURR_DIR}/../tmp/flux-system-ssh-key.json"

encrypt_secret "flux-system-ssh-key.json" "${CURR_DIR}/../01_gitops/dev/"
git add "${CURR_DIR}/../01_gitops/dev/flux-system-ssh-key.json" && git commit -m "Update flux ssh secret" && git push

kustomize build "$CURR_DIR/../01_gitops/dev" | kubectl apply -f -

"$CURR_DIR/../hack/update-local-ca-certs.sh"

kubectl create namespace cert-manager
kustomize build "$CURR_DIR/../02_bootstrap/dev" | kubectl apply -f -

echo "Use with export KUBECONFIG=${KUBECONFIG}"
