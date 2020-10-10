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
	kustomize build ./03_infrastructure/sealed-secrets/base | kubectl apply -f -
	kustomize build ./03_infrastructure/cert-manager/base/ | kubectl apply -f -
	kustomize build ./03_infrastructure/certificate-authority/dev/ | kubectl apply -f -
	kustomize build ./04_datastore/longhorn/base/ | kubectl apply -f -
	helm template postgres-operator 04_datastore/postgres-operator --namespace postgres-operator --include-crds > 04_data-store/postgres-operator/base/all.yaml && kustomize build 04_data-store/postgres-operator/base | kubectl -n postgres-operator apply -f -
	kustomize build ./05_observability/prometheus-operator/crds | kubectl apply -f -
	helm template prometheus-operator 05_observability/prometheus-operator --namespace monitoring > 05_observability/prometheus-operator/base/all.yaml && kustomize build 05_observability/prometheus-operator/dev | kubectl apply -f -
	kustomize build ./01_argocd/dev/ | kubectl apply -f -
	kustomize build ./02_applications/dev/ | kubectl apply -f -

#helm template $ARGOCD_APP_NAME . --namespace $ARGOCD_APP_NAMESPACE $ADDITIONAL_HELM_ARGS > base/all.yaml && kustomize build $ENVIRONMENT"
update-argocd-secret:
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"admin.password": "'$$(bcrypt-tool hash $(ARGOCD_PASSWORD) 10)'","admin.passwordMtime": "'$$(date +%FT%T%Z)'"}}'
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"oidc.keycloak.clientSecret": "'$(OIDC_SECRET)'"}}'
