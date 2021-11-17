CURRENT_DIR=$(shell pwd)

ENVIRONMENT=dev
ROOT_DOMAIN=192.168.0.13.nip.io

ARGOCD_PASSWORD := $(shell gopass clusters/$(ENVIRONMENT)/argocd)
OIDC_SECRET := $(shell gopass clusters/$(ENVIRONMENT)/oidc/secret)

update-local-ca:
	./hack/update-local-ca-certs.sh

update-secrets:
	./hack/create-secrets.sh $(ENVIRONMENT) $(ROOT_DOMAIN)

bootstrap-cluster:
	kustomize build ./00_global-resources | kubectl apply -f -
	kustomize build infrastructure/pki/sealed-secrets/base | kubectl apply -f -
	kustomize build infrastructure/pki/cert-manager/base/ | kubectl apply -f -
	kustomize build infrastructure/pki/certificate-authority/dev/ | kubectl apply -f -
	helm template rook infrastructure/storage/rook --namespace rook-ceph  \
		> infrastructure/storage/rook/base/all.yaml \
		&& kustomize build infrastructure/storage/rook/base/ \
		| kubectl -n rook-ceph apply -f -
	kustomize build infrastructure/storage/local-path-provisioner/base/ | kubectl apply -f -
	kustomize build infrastructure/storage/longhorn/base/ | kubectl apply -f -
	kubectl apply -k infrastructure/argocd-apps/dev/secrets
	helm dep up infrastructure/ingress/traefik
	helm template traefik infrastructure/ingress/traefik --namespace traefik --include-crds \
		> infrastructure/ingress/traefik/base/all.yaml \
		&& kustomize build infrastructure/ingress/traefik/dev \
		| kubectl -n traefik apply -f -
	kustomize build infrastructure/observability/prometheus-operator/crds \
		| kubectl apply -f -
	helm dep up infrastructure/database/kubedb
	helm template kubedb infrastructure/database/kubedb --namespace kube-system  \
		> infrastructure/database/kubedb/base/all.yaml \
	  	&& kustomize build infrastructure/database/kubedb/base/ \
	  	| kubectl -n kube-system apply -f -
	helm dep up infrastructure/database/kubedb-catalog
	helm template kubedb-catalog infrastructure/database/kubedb-catalog --namespace kube-system  \
		> infrastructure/database/kubedb-catalog/base/all.yaml \
		&& kustomize build infrastructure/database/kubedb-catalog/base/ \
		| kubectl -n kube-system apply -f -
	helm dep up  infrastructure/observability/prometheus-operator
	helm template prometheus-operator infrastructure/observability/prometheus-operator --namespace monitoring \
		> infrastructure/observability/prometheus-operator/base/all.yaml \
		&& kustomize build infrastructure/observability/prometheus-operator/dev \
		| kubectl apply -f -
	helm dep up infrastructure/identity/keycloak
	helm template keycloak infrastructure/identity/keycloak --namespace keycloak \
		> infrastructure/identity/keycloak/base/all.yaml \
		&& kustomize build infrastructure/identity/keycloak/dev \
		| kubectl -n keycloak apply -f -
	kustomize build ./01_argocd/dev/ | kubectl -n argocd apply -f -
	kustomize build infrastructure/ingress/external-access/dev | kubectl apply -f -
	kustomize build ./02_bootstrap/overlays/dev/ | kubectl -n argocd apply -f -

#helm template $ARGOCD_APP_NAME . --namespace $ARGOCD_APP_NAMESPACE $ADDITIONAL_HELM_ARGS > base/all.yaml && kustomize build $ENVIRONMENT"
update-argocd-secret:
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"admin.password": "'$$(bcrypt-tool hash $(ARGOCD_PASSWORD) 10)'","admin.passwordMtime": "'$$(date +%FT%T%Z)'"}}'
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"oidc.keycloak.clientSecret": "'$(OIDC_SECRET)'"}}'

