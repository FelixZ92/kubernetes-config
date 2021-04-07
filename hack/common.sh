#!/usr/bin/env bash

deploy_global_resources() {
  BASEDIR="${1}"
  echo "$BASEDIR"
  kustomize build "$BASEDIR/00_global-resources" |
    kubectl apply -f -
}

deploy_sealed_secrets() {
  BASEDIR="${1}"
  kustomize build "$BASEDIR/03_infrastructure/pki/sealed-secrets/base/" | \
    kubectl apply -f -
  kubectl wait --for=condition=available --timeout=600s deployment/sealed-secrets-controller -n kube-system
}

apply_secrets() {
  BASEDIR="${1}"
  ENVIRONMENT="${2}"
  echo "Waiting for sealed secrets to become available"
  kubectl wait --for=condition=ready --timeout=600s helmreleases.helm.toolkit.fluxcd.io -n kube-system sealed-secrets-controller
  gopass-kubeseal applyBulk -f "$BASEDIR/02_bootstrap/overlays/dev/secrets.yaml"
}

deploy_flux() {
  BASEDIR="${1}"
  KEYFILE="${2}"
  KNOWN_HOSTS_FILE="${3}"
  ENVIRONMENT="${4}"

  kubectl --namespace flux-system \
    create secret generic flux-system \
    --from-file="identity.pub=$KEYFILE.pub" \
    --from-file="identity=$KEYFILE" \
    --from-file="known_hosts=$KNOWN_HOSTS_FILE" \
    || echo "secret flux-system already exists"

  kustomize build "${BASEDIR}/01_gitops/base/" | kubectl apply -f -
  kubectl wait --for=condition=available --timeout=600s deployment/kustomize-controller -n flux-system
}

deploy_crds() {
  BASEDIR="${1}"
  kustomize build "${BASEDIR}/03_infrastructure/pki/crds" \
    | kubectl apply -f -
  kustomize build "${BASEDIR}/03_infrastructure/observability/crds" \
    | kubectl apply -f -
  kustomize build "${BASEDIR}/03_infrastructure/ingress/crds" \
    | kubectl apply -f -
}
