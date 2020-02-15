PASSWORD_LENGTH = 32
SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets
SEALED_SECRETS_CONTROLLER_NAMESPACE=sealed-secrets

ifdef KUBE_MANIFEST
NAMESPACE = $(shell cat ${KUBE_MANIFEST} | yq  -r .metadata.namespace)
SECRET_NAME = $(shell cat ${KUBE_MANIFEST} | yq  -r .metadata.name)
SECRET_KEY = $(shell cat ${KUBE_MANIFEST} | yq  -r '.spec.encryptedData | to_entries[].key')
endif

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
