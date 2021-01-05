#!/usr/bin/env bash

deploy_global_resources() {
  BASEDIR="${1}"
  echo "$BASEDIR"
  kustomize build "$BASEDIR/00_global-resources" \
    | kubectl apply -f -
}

deploy_sealed_secrets() {
  BASEDIR="${1}"
  kustomize build "$BASEDIR/03_infrastructure/pki/sealed-secrets/base/" \
    | kubectl apply -f -
  kubectl wait --for=condition=available --timeout=600s deployment/sealed-secrets-controller -n kube-system
}

deploy_flux() {
  BASEDIR="${1}"
  KEYFILE="${2}"
  KNOWN_HOSTS_FILE="${3}"
  ENVIRONMENT="${4}"
  kubectl create ns flux-system || echo "Namespace flux-system already exists"

  kubectl --dry-run=client \
    --namespace flux-system \
    create secret generic flux-system \
    --from-file="identity.pub=$KEYFILE.pub" \
    --from-file="identity=$KEYFILE" \
    --from-file="known_hosts=$KNOWN_HOSTS_FILE" \
    -o json \
     >"${CURR_DIR}/../tmp/flux-system-ssh-key.json"

  encrypt_secret "flux-system-ssh-key.json" "${BASEDIR}/01_gitops/${ENVIRONMENT}/"
  git add "${BASEDIR}/01_gitops/${ENVIRONMENT}/flux-system-ssh-key.json" && git commit -m "Update flux ssh secret" && git push

  kustomize build "${BASEDIR}/01_gitops/${ENVIRONMENT}/" | kubectl apply -f -
}
