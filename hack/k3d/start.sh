#!/usr/bin/env bash

set -eo pipefail

#set -x

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"; exit 1
}

BASEDIR=$(dirname "$(dirname "$CURR_DIR")")

export BASE_DOMAIN=127.0.0.1.nip.io
export ENVIRONMENT=dev

# shellcheck source=hack/secrets/secrets-common.sh
source "$CURR_DIR/../secrets/common.sh"
# shellcheck source=hack/common.sh
source "$CURR_DIR/../common.sh"

k3d cluster create local \
  --config "${CURR_DIR}/config.yaml" \
  -v "${CURR_DIR}/psp.yaml:/var/lib/rancher/k3s/server/manifests/psp.yaml@server:*" || echo "cluster local already exists"

export KUBECONFIG=$(k3d kubeconfig write local)
kubectl label node k3d-local-agent-0 storage=local --overwrite
kubectl label node k3d-local-agent-1 storage=local --overwrite
kubectl label node k3d-local-agent-2 storage=local --overwrite
kubectl label node k3d-local-agent-2 node.kubernetes.io/ingress=traefik --overwrite

export LOCALHOST_GATEWAY=$(kubectl -n kube-system get cm coredns -o jsonpath='{.data.NodeHosts}' | grep 'host.k3d.internal' | cut -d' ' -f1)

envsubst '${LOCALHOST_GATEWAY}' < "${CURR_DIR}/coredns-patch.yaml" > "${CURR_DIR}/coredns-patch-substituted.yaml"

test=$(kubectl get cm coredns -n kube-system --template='{{.data.NodeHosts}}' \
  | sed -n -E -e '/[0-9\.]{4,12}\s+keycloak\.host\.k3d\.internal$/!p' -e "\$a${LOCALHOST_GATEWAY} keycloak.host.k3d.internal" \
  | sed -n -E -e '/[0-9\.]{4,12}\s+ocis\.host\.k3d\.internal$/!p' -e "\$a${LOCALHOST_GATEWAY} ocis.host.k3d.internal" \
  | tr '\n' '^' \
  | xargs -0 printf '{"data": {"NodeHosts":"%s"}}'\
  | sed -E 's%\^%\\n%g') && kubectl patch cm coredns -n kube-system -p="$test"

kubectl rollout restart deployment coredns -n kube-system

deploy_global_resources "${BASEDIR}"

deploy_flux "${BASEDIR}" "$HOME/.ssh/id_ed25519_gitlab" "$BASEDIR/hack/known_hosts" "${ENVIRONMENT}"

kustomize build "$BASEDIR/system/sources" | kubectl apply -f -
kubectl apply -f "$BASEDIR/system/bootstrap.yaml"

kubectl wait --for=condition=ready --timeout=600s kustomizations.kustomize.toolkit.fluxcd.io -n kube-system bootstrap

# apply_secrets "${BASEDIR}" "${ENVIRONMENT}"

update_local_ca_certs "${BASEDIR}"

echo "Use with export KUBECONFIG=${KUBECONFIG}"
