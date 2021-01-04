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
  -v "${CURR_DIR}/psp.yaml:/var/lib/rancher/k3s/server/manifests/psp.yaml"

KUBECONFIG=$(k3d kubeconfig write local)

kustomize build "$CURR_DIR/../00_global-resources" \
  | kubectl --kubeconfig "${KUBECONFIG}" apply -f -
kustomize build "$CURR_DIR/../03_infrastructure/pki/sealed-secrets/base/" \
  | kubectl --kubeconfig "${KUBECONFIG}" apply -f -

kubectl --kubeconfig "${KUBECONFIG}" create ns flux-system
kubectl --kubeconfig "${KUBECONFIG}" \
  --dry-run=client \
  --namespace flux-system \
  create secret generic flux-system \
  --from-file="identity.pub=$HOME/.ssh/gitlab_deploy_key.pub" \
  --from-file="identity=$HOME/.ssh/gitlab_deploy_key" \
  --from-file="known_hosts=$CURR_DIR/../hack/known_hosts" \
  -o json \
   >"${CURR_DIR}/../tmp/flux-system-ssh-key.json"

encrypt_secret "flux-system-ssh-key.json" .

echo "Use with export KUBECONFIG=${KUBECONFIG}"
