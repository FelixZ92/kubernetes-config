CURRENT_DIR=$(shell pwd)

ENVIRONMENT=dev
ROOT_DOMAIN=192.168.0.13.xip.io

ARGOCD_PASSWORD := $(shell gopass clusters/$(ENVIRONMENT)/argocd)
OIDC_SECRET := $(shell gopass clusters/$(ENVIRONMENT)/oidc/secret)

update-local-ca:
	./hack/update-local-ca-certs.sh

update-secrets:
	./hack/create-secrets.sh $(ENVIRONMENT) $(ROOT_DOMAIN)

bootstrap-cluster:
	kustomize build ./00_global-resources | kubectl apply -f -
	kustomize build ./03_infrastructure/pki/sealed-secrets/base | kubectl apply -f -
	kustomize build ./03_infrastructure/pki/cert-manager/base/ | kubectl apply -f -
	kustomize build ./03_infrastructure/pki/certificate-authority/dev/ | kubectl apply -f -
	kustomize build ./03_infrastructure/storage/longhorn/base/ | kubectl apply -f -
	kustomize build ./03_infrastructure/database/postgres-operator/crds/ | kubectl apply -f -
	kubectl apply -f ./02_applications/dev/secrets
	helm template traefik ./03_infrastructure/ingress/traefik --namespace traefik --include-crds > ./03_infrastructure/ingress/traefik/base/all.yaml && kustomize build ./03_infrastructure/ingress/traefik/dev | kubectl -n traefik apply -f -
	helm template kubedb ./03_infrastructure/database/kubedb --namespace kube-system  > ./03_infrastructure/database/kubedb/base/all.yaml && kustomize build 03_infrastructure/database/kubedb/base/ | kubectl -n kube-system apply -f -
	helm template postgres-operator ./03_infrastructure/database/postgres-operator --namespace postgres-operator --include-crds > ./03_infrastructure/database/postgres-operator/base/all.yaml && kustomize build 03_infrastructure/database/postgres-operator/base | kubectl -n postgres-operator apply -f -
	kustomize build ./03_infrastructure/observability/prometheus-operator/crds | kubectl apply -f -
	helm template prometheus-operator 03_infrastructure/observability/prometheus-operator --namespace monitoring > 03_infrastructure/observability/prometheus-operator/base/all.yaml && kustomize build 03_infrastructure/observability/prometheus-operator/dev | kubectl apply -f -
	helm template keycloak ./06_identity/keycloak --namespace keycloak > ./06_identity/keycloak/base/all.yaml && kustomize build ./06_identity/keycloak/dev | kubectl apply -f -
	kustomize build ./01_argocd/dev/ | kubectl apply -f -
	kustomize build ./03_infrastructure/ingress/external-access/dev | kubectl apply -f -
	kustomize build ./02_applications/dev/ | kubectl apply -f -

#helm template $ARGOCD_APP_NAME . --namespace $ARGOCD_APP_NAMESPACE $ADDITIONAL_HELM_ARGS > base/all.yaml && kustomize build $ENVIRONMENT"
update-argocd-secret:
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"admin.password": "'$$(bcrypt-tool hash $(ARGOCD_PASSWORD) 10)'","admin.passwordMtime": "'$$(date +%FT%T%Z)'"}}'
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"oidc.keycloak.clientSecret": "'$(OIDC_SECRET)'"}}'
