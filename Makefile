CURRENT_DIR=$(shell pwd)

ENVIRONMENT=dev
ROOT_DOMAIN=192.168.0.13.xip.io

ARGOCD_PASSWORD := $(shell gopass clusters/$(ENVIRONMENT)/argocd)
OIDC_SECRET := $(shell gopass clusters/$(ENVIRONMENT)/oidc/secret)

update-local-ca:
	./hack/update-local-ca-certs.sh

update-secrets:
	./hack/create-secrets.sh $(ENVIRONMENT) $(ROOT_DOMAIN)

bootstrap-cluster: update-secrets
	kustomize build ./longhorn/base/ | kubectl apply -f -
	kustomize build ./00_argocd/dev/ | kubectl apply -f -
	kustomize build ./01_argocd-application/dev/ | kubectl apply -f -
	kustomize build ./02_applications/dev/ | kubectl apply -f -

update-argocd-secret:
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"admin.password": "'$$(bcrypt-tool hash $(ARGOCD_PASSWORD) 10)'","admin.passwordMtime": "'$$(date +%FT%T%Z)'"}}'
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"oidc.keycloak.clientSecret": "'$(OIDC_SECRET)'"}}'

test-secrets:
	./hack/create-secrets.sh dev
