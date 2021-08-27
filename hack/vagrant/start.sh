#!/usr/bin/env bash

set -eo pipefail

set -x

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
[ -d "$CURR_DIR" ] || {
  echo "FATAL: no current dir (maybe running in zsh?)"; exit 1
}

BASEDIR=$(dirname "$(dirname "$CURR_DIR")")

ENVIRONMENT=vagrant

# shellcheck source=hack/secrets/secrets-common.sh
source "$CURR_DIR/../secrets/common.sh"
# shellcheck source=hack/common.sh
source "$CURR_DIR/../common.sh"

export KUBECONFIG="${HOME}/kubeconfig-rke2-vagrant.yaml"

kubectl annotate node node1 'node.longhorn.io/default-disks-config=[{"name":"local-disk","path":"/var/lib/longhorn","allowScheduling":true,"tags":["ssd","fast"]}]' --overwrite
kubectl annotate node node2 'node.longhorn.io/default-disks-config=[{"name":"local-disk","path":"/var/lib/longhorn","allowScheduling":true,"tags":["ssd","fast"]}]' --overwrite
kubectl annotate node node3 'node.longhorn.io/default-disks-config=[{"name":"local-disk","path":"/var/lib/longhorn","allowScheduling":true,"tags":["ssd","fast"]}]' --overwrite

kubectl annotate node node1 'node.longhorn.io/default-node-tags=["fast","storage"]' --overwrite
kubectl annotate node node2 'node.longhorn.io/default-node-tags=["fast","storage"]' --overwrite
kubectl annotate node node3 'node.longhorn.io/default-node-tags=["fast","storage"]' --overwrite

deploy_global_resources "${BASEDIR}"

deploy_crds "${BASEDIR}"

#deploy_sealed_secrets "${BASEDIR}"

deploy_flux "${BASEDIR}" "$HOME/.ssh/gitlab_deploy_key" "$BASEDIR/hack/known_hosts" "${ENVIRONMENT}"

kustomize build "$BASEDIR/02_bootstrap/overlays/${ENVIRONMENT}" | kubectl apply -f -

kubectl wait --for=condition=ready --timeout=600s kustomizations.kustomize.toolkit.fluxcd.io -n kube-system pki

apply_secrets "${BASEDIR}" "${ENVIRONMENT}"

update_local_ca_certs "${BASEDIR}"

#
#echo "Use with export KUBECONFIG=${KUBECONFIG}"
