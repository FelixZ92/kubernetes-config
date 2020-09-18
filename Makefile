PASSWORD_LENGTH = 32
SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets-controller
SEALED_SECRETS_CONTROLLER_NAMESPACE=kube-system

CURRENT_DIR=$(shell pwd)
CA_CERTS_FOLDER=$(CURRENT_DIR)/.certs
ENVIRONMENT_DEV=dev

ifdef KUBE_MANIFEST
NAMESPACE = $(shell cat ${KUBE_MANIFEST} | yq  -r .metadata.namespace)
SECRET_NAME = $(shell cat ${KUBE_MANIFEST} | yq  -r .metadata.name)
SECRET_KEY = $(shell cat ${KUBE_MANIFEST} | yq  -r '.spec.encryptedData | to_entries[].key')
endif

ENVIRONMENT=dev
export ROOT_DOMAIN=192.168.0.13.xip.io# export needed for grafana generic oauth hack
KEYCLOAK_PASSWORD := $(shell gopass clusters/$(ENVIRONMENT)/keycloak/admin)
GRAFANA_PASSWORD := $(shell gopass clusters/$(ENVIRONMENT)/grafana)
export OIDC_SECRET := $(shell gopass clusters/$(ENVIRONMENT)/oidc/secret)
export OIDC_CLIENT_ID = k8s

OIDC_NAMESPACES = monitoring traefik postgres-operator argocd keycloak longhorn-system dashboard

echo-keycloak:
	echo $(KEYCLOAK_PASSWORD)
gen-secret/uuid: gen-secret/check-vars gen-secret/assert-tmp-dir
	uuidgen -r | tr -d '\n' > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-secret/urandom: gen-secret/check-vars gen-secret/assert-tmp-dir
	@< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${PASSWORD_LENGTH} > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-secret/manuel: gen-secret/check-vars gen-secret/assert-tmp-dir
	@if test -z $(PASSWORD) ; then echo "PASSWORD not set"; exit 1; fi
	@echo $(PASSWORD) > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-sealed-secret/uuid: gen-secret/uuid gen-kube-secret gen-sealed-secret

gen-sealed-secret/urandom: gen-secret/urandom gen-kube-secret gen-sealed-secret

gen-sealed-secret/manuel: gen-secret/manuel gen-kube-secret gen-sealed-secret

gen-kube-secret: gen-secret/check-bin
	@kubectl -n $(NAMESPACE) create secret generic $(SECRET_NAME) --dry-run --from-file=$(SECRET_KEY)=./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp -o json > ./tmp/$(SECRET_NAME).json

gen-sealed-secret:
	@kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
		--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
		 < ./tmp/$(SECRET_NAME).json > ./tmp/$(SECRET_NAME)-sealed.json
	@cat ./tmp/$(SECRET_NAME)-sealed.json | yq . -y > ./tmp/$(SECRET_NAME)-sealed.yaml
	@echo "You can copy ./tmp/$(SECRET_NAME)-sealed.yaml to desired location within this repository and commit it"

gen-secret/check-vars:
	if test -z $(NAMESPACE) ; then echo "NAMESPACE not set"; exit 1; fi
	if test -z $(SECRET_NAME) ; then echo "SECRET_NAME not set"; exit 1; fi
	if test -z $(SECRET_KEY) ; then echo "SECRET_KEY not set"; exit 1; fi

gen-secret/check-bin:
	@jq --version foo >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
	@yq --version foo >/dev/null 2>&1 || { echo >&2 "I require yq but it's not installed.  Aborting."; exit 1; }
	@kubectl version foo >/dev/null 2>&1 || { echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }
	@kubeseal --version foo >/dev/null 2>&1 || { echo >&2 "I require kubeseal but it's not installed.  Aborting."; exit 1; }

gen-secret/assert-tmp-dir:
	@mkdir -p ./tmp

re-encrypt-secret: gen-secret/check-bin gen-secret/assert-tmp-dir
	@if test -z $(KUBE_MANIFEST) ; then echo "KUBE_MANIFEST not set"; exit 1; fi
	@kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
		--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
		--re-encrypt < $(KUBE_MANIFEST) | yq . -y > tmp.yaml
	@mv tmp.yaml $(KUBE_MANIFEST)

re-encrypt-all:
	@make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret1-sealed.yaml
	@make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret2-sealed.yaml
	@make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret3-sealed.yaml
	@make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret4-sealed.yaml

rotate-secret/urandom:
	@if test -z $(KUBE_MANIFEST) ; then echo "KUBE_MANIFEST not set"; exit 1; fi
	@make gen-sealed-secret/urandom NAMESPACE=${NAMESPACE} \
		SECRET_NAME=${SECRET_NAME} \
		SECRET_KEY=${SECRET_KEY}
	@mv ./tmp/$(SECRET_NAME)-sealed.yaml $(KUBE_MANIFEST)
	@echo "Commit changes to apply the rotated secret"

rotate-secret/uuid:
	@if test -z $(KUBE_MANIFEST) ; then echo "KUBE_MANIFEST not set"; exit 1; fi
	@make gen-sealed-secret/uuid NAMESPACE=${NAMESPACE} \
		SECRET_NAME=${SECRET_NAME} \
		SECRET_KEY=${SECRET_KEY}
	@mv ./tmp/$(SECRET_NAME)-sealed.yaml $(KUBE_MANIFEST)
	@echo "Commit changes to apply the rotated secret"

rotate-secret/manuel:
	@if test -z $(KUBE_MANIFEST) ; then echo "KUBE_MANIFEST not set"; exit 1; fi
	@make gen-sealed-secret/manuel NAMESPACE=${NAMESPACE} \
		SECRET_NAME=${SECRET_NAME} \
		SECRET_KEY=${SECRET_KEY}
	@mv ./tmp/$(SECRET_NAME)-sealed.yaml $(KUBE_MANIFEST)
	@echo "Commit changes to apply the rotated secret"

rotate-all:
#	@make rotate-secret/urandom KUBE_MANIFEST=./test-secrets/secret1-sealed.yaml
#	@make rotate-secret/urandom KUBE_MANIFEST=./test-secrets/secret2-sealed.yaml
#	@make rotate-secret/urandom KUBE_MANIFEST=./test-secrets/secret3-sealed.yaml
#	@make rotate-secret/urandom KUBE_MANIFEST=./test-secrets/secret4-sealed.yaml
	@make rotate-secret/urandom KUBE_MANIFEST=./releases/06_keycloak/keycloak-admin-sealed-secret.yaml
	@make rotate-secret/urandom KUBE_MANIFEST=./releases/06_keycloak/cluster-user-credentials-sealed.yaml
	@make rotate-secret/urandom KUBE_MANIFEST=./releases/06_keycloak/cluster-admin-credentials-sealed.yaml
	@make rotate-secret/urandom KUBE_MANIFEST=./releases/06_keycloak/realm-admin-credentials-sealed.yaml
	@make rotate-secret/uuid KUBE_MANIFEST=./releases/04_traefik-system/traefik-dashboard-client-sealed.yaml
	@git commit -am "Rotate secrets"
	@git push
	@fluxctl  --k8s-fwd-ns fluxcd sync
test2:
	echo "$(GRAFANA_PASSWORD)"
blub:
	kubectl version foo
	kubectl version foo >/dev/null 2>&1 || { echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }

test:
	for n in $(OIDC_NAMESPACES); do \
		echo $$n ; \
	done

create-oidc-secret:
	@if [ -z "$(OIDC_SECRET)" ]; then echo "OIDC_SECRET not set, exit"; exit 1; fi
	@if [ -z "$(OIDC_CLIENT_ID)" ]; then echo "OIDC_CLIENT_ID not set, exit"; exit 1; fi
	for n in $(OIDC_NAMESPACES); do \
		echo $$n ; \
		kubectl -n $$n --dry-run=client create secret generic oidc-secret \
			--from-literal=clientid="$(OIDC_CLIENT_ID)" --from-literal=secret="$(OIDC_SECRET)" -o json \
			> $(CURRENT_DIR)/tmp/$$n-oidc-secret.json ; \
		kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
				--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
				 < $(CURRENT_DIR)/tmp/$$n-oidc-secret.json \
				 > $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/$$n-oidc-secret.json ; \
		git add $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/$$n-oidc-secret.json ; \
	done
	git commit -m "Re-encrypt oidc secret"
	git push

create-signing-secret:
	@for n in $(OIDC_NAMESPACES); do \
  		openssl rand -hex 16 | tr -d '\n' > ./tmp/$$n-signing-secret.tmp ; \
		kubectl -n $$n create secret generic oidc-signing-secret --dry-run=client \
			--from-file=secret=./tmp/$$n-signing-secret.tmp -o json > ./tmp/$$n-signing-secret.json ; \
		kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
					--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
					 < $(CURRENT_DIR)/tmp/$$n-signing-secret.json \
					 > $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/$$n-signing-secret-sealed.json ; \
		git add $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/$$n-signing-secret-sealed.json ; \
	done ;
	git commit -m "Re-encrypt grafana secret" && \
	git push

create-keycloak-admin-secret:
	if [ -z "$(KEYCLOAK_PASSWORD)" ]; then echo "KEYCLOAK_PASSWORD not set, exit"; exit 1; fi
	@kubectl -n keycloak --dry-run=client create secret generic keycloak-admin-user \
		--from-literal=username=keycloak --from-literal=password="$(KEYCLOAK_PASSWORD)" -o json \
		> $(CURRENT_DIR)/tmp/keycloak-admin-user.json
	@kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
			--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
			 < $(CURRENT_DIR)/tmp/keycloak-admin-user.json \
			 > $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/keycloak-admin-user-sealed.json
	@git add $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/keycloak-admin-user-sealed.json && \
		git commit -m "Re-encrypt keycloak secret" && \
		git push

create-grafana-secret:
	if [ -z "$(GRAFANA_PASSWORD)" ]; then echo "GRAFANA_PASSWORD not set, exit"; exit 1; fi
	@kubectl -n monitoring --dry-run=client create secret generic grafana-admin-user \
		--from-literal=username=admin --from-literal=password="$(GRAFANA_PASSWORD)" -o json \
		> $(CURRENT_DIR)/tmp/grafana-admin-user.json
	@kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
			--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
			 < $(CURRENT_DIR)/tmp/grafana-admin-user.json \
			 > $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/grafana-admin-user-sealed.json
	@git add $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/grafana-admin-user-sealed.json && \
		git commit -m "Re-encrypt grafana secret" && \
		git push

create-grafana-generic-oauth-secret:
	@if [ -z "$(OIDC_SECRET)" ]; then echo "OIDC_SECRET not set, exit"; exit 1; fi
	@if [ -z "$(OIDC_CLIENT_ID)" ]; then echo "OIDC_CLIENT_ID not set, exit"; exit 1; fi
	@if [ "$(ENVIRONMENT)" = "dev" ]; then export SKIP_TLS=true; else export SKIP_TLS=false; fi ; \
 		envsubst '$${ROOT_DOMAIN} $${OIDC_CLIENT_ID} $${OIDC_SECRET} $${SKIP_TLS}' \
		< hack/grafana-generic-auth-secret.yaml > tmp/grafana-generic-auth-secret.yaml
	@kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
			--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
			 < $(CURRENT_DIR)/tmp/grafana-generic-auth-secret.yaml \
			 > $(CURRENT_DIR)/prometheus-operator/$(ENVIRONMENT)/grafana-generic-auth-secret.yaml


# kudos to Sébastien Dubois (https://itnext.io/deploying-tls-certificates-for-local-development-and-production-using-kubernetes-cert-manager-9ab46abdd569)
generate-local-ca:
	@rm -rf "$(CA_CERTS_FOLDER)" && \
		mkdir -p "$(CA_CERTS_FOLDER)/$(ENVIRONMENT_DEV)" && \
		mkdir -p $(CURRENT_DIR)/tmp
	@CAROOT=$(CA_CERTS_FOLDER)/$(ENVIRONMENT_DEV) mkcert -install

update-local-ca-secrets:
	@kubectl -n cert-manager create secret tls dev-ca-secret \
		--key=$(CA_CERTS_FOLDER)/$(ENVIRONMENT_DEV)/rootCA-key.pem \
		--cert=$(CA_CERTS_FOLDER)/$(ENVIRONMENT_DEV)/rootCA.pem \
		--dry-run=client -o json \
		> $(CURRENT_DIR)/tmp/dev-ca-secret.json

	@kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
			--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
			 < $(CURRENT_DIR)/tmp/dev-ca-secret.json \
			 > $(CURRENT_DIR)/cert-manager/dev/dev-ca-secret-sealed.json

	@git add $(CURRENT_DIR)/cert-manager/dev/dev-ca-secret-sealed.json && \
		git commit -m "Update dev CA" && \
		git push

update-secrets: create-grafana-secret create-keycloak-admin-secret create-oidc-secret create-signing-secret update-local-ca-secrets

create-local-ca-secrets:
	for n in $(OIDC_NAMESPACES); do \
		echo $$n ; \
		kubectl -n $$n create secret tls dev-ca-secret \
				--key=$(CA_CERTS_FOLDER)/$(ENVIRONMENT_DEV)/rootCA-key.pem \
        		--cert=$(CA_CERTS_FOLDER)/$(ENVIRONMENT_DEV)/rootCA.pem \
        		--dry-run=client -o json \
        		> $(CURRENT_DIR)/tmp/$$n-dev-ca-secret.json ; \
		kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
		    	--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
		    	 < $(CURRENT_DIR)/tmp/$$n-dev-ca-secret.json \
		    	 > $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/$$n-dev-ca-secret-sealed.json ; \
		git add $(CURRENT_DIR)/02_applications/$(ENVIRONMENT)/secrets/$$n-dev-ca-secret-sealed.json ; \
	done
	git commit -m "Re-encrypt oidc secret" && \
	git push

bootstrap-cluster: update-secrets
	kustomize build ./longhorn/base/ | kubectl apply -f -
	kustomize build ./00_argocd/dev/ | kubectl apply -f -
	kustomize build ./01_argocd-application/dev/ | kubectl apply -f -
	kustomize build ./02_applications/dev/ | kubectl apply -f -

# TODO: service accounts for deploy hooks
