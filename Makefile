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
	kustomize build ./03_infrastructure/pki/sealed-secrets/base | kubectl apply -f -
	kustomize build ./03_infrastructure/pki/cert-manager/base/ | kubectl apply -f -
	kustomize build ./03_infrastructure/pki/certificate-authority/dev/ | kubectl apply -f -
	helm template rook ./03_infrastructure/storage/rook --namespace rook-ceph  \
		> ./03_infrastructure/storage/rook/base/all.yaml \
		&& kustomize build 03_infrastructure/storage/rook/base/ \
		| kubectl -n rook-ceph apply -f -
	kustomize build ./03_infrastructure/storage/local-path-provisioner/base/ | kubectl apply -f -
	kustomize build ./03_infrastructure/storage/longhorn/base/ | kubectl apply -f -
	kubectl apply -k ./03_infrastructure/argocd-apps/dev/secrets
	helm dep up ./03_infrastructure/ingress/traefik
	helm template traefik ./03_infrastructure/ingress/traefik --namespace traefik --include-crds \
		> ./03_infrastructure/ingress/traefik/base/all.yaml \
		&& kustomize build ./03_infrastructure/ingress/traefik/dev \
		| kubectl -n traefik apply -f -
	kustomize build ./03_infrastructure/observability/prometheus-operator/crds \
		| kubectl apply -f -
	helm dep up ./03_infrastructure/database/kubedb
	helm template kubedb ./03_infrastructure/database/kubedb --namespace kube-system  \
		> ./03_infrastructure/database/kubedb/base/all.yaml \
	  	&& kustomize build 03_infrastructure/database/kubedb/base/ \
	  	| kubectl -n kube-system apply -f -
	helm dep up ./03_infrastructure/database/kubedb-catalog
	helm template kubedb-catalog ./03_infrastructure/database/kubedb-catalog --namespace kube-system  \
		> ./03_infrastructure/database/kubedb-catalog/base/all.yaml \
		&& kustomize build 03_infrastructure/database/kubedb-catalog/base/ \
		| kubectl -n kube-system apply -f -
	helm dep up  ./03_infrastructure/observability/prometheus-operator
	helm template prometheus-operator ./03_infrastructure/observability/prometheus-operator --namespace monitoring \
		> 03_infrastructure/observability/prometheus-operator/base/all.yaml \
		&& kustomize build 03_infrastructure/observability/prometheus-operator/dev \
		| kubectl apply -f -
	helm dep up ./03_infrastructure/identity/keycloak
	helm template keycloak ./03_infrastructure/identity/keycloak --namespace keycloak \
		> ./03_infrastructure/identity/keycloak/base/all.yaml \
		&& kustomize build ./03_infrastructure/identity/keycloak/dev \
		| kubectl -n keycloak apply -f -
	kustomize build ./01_argocd/dev/ | kubectl -n argocd apply -f -
	kustomize build ./03_infrastructure/ingress/external-access/dev | kubectl apply -f -
	kustomize build ./02_bootstrap/overlays/dev/ | kubectl -n argocd apply -f -

#helm template $ARGOCD_APP_NAME . --namespace $ARGOCD_APP_NAMESPACE $ADDITIONAL_HELM_ARGS > base/all.yaml && kustomize build $ENVIRONMENT"
update-argocd-secret:
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"admin.password": "'$$(bcrypt-tool hash $(ARGOCD_PASSWORD) 10)'","admin.passwordMtime": "'$$(date +%FT%T%Z)'"}}'
	@kubectl -n argocd patch secret argocd-secret \
    	-p '{"stringData": {"oidc.keycloak.clientSecret": "'$(OIDC_SECRET)'"}}'

