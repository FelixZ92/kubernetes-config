PASSWORD_LENGTH = 32
SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets
SEALED_SECRETS_CONTROLLER_NAMESPACE=sealed-secrets

gen-secret/uuid: gen-secret/check-vars gen-secret/assert-tmp-dir
	uuidgen -r | tr -d '\n' > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-sealed-secret/uuid: gen-secret/uuid gen-kube-secret gen-sealed-secret

gen-sealed-secret/urandom: gen-secret/urandom gen-kube-secret gen-sealed-secret

gen-secret/urandom: gen-secret/check-vars gen-secret/assert-tmp-dir
	< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${PASSWORD_LENGTH} > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-kube-secret: gen-secret/check-bin
	kubectl -n $(NAMESPACE) create secret generic $(SECRET_NAME) --dry-run --from-file=$(SECRET_KEY)=./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp -o json > ./tmp/$(SECRET_NAME).json

gen-sealed-secret:
	kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
		--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
		 < ./tmp/$(SECRET_NAME).json > ./tmp/$(SECRET_NAME)-sealed.json
	cat ./tmp/$(SECRET_NAME)-sealed.json | yq . -y > ./tmp/$(SECRET_NAME)-sealed.yaml
	echo "Copy to desired location"

gen-secret/check-vars:
	if test -z $(NAMESPACE) ; then echo "NAMESPACE not set"; exit 1; fi
	if test -z $(SECRET_NAME) ; then echo "SECRET_NAME not set"; exit 1; fi
	if test -z $(SECRET_KEY) ; then echo "SECRET_KEY not set"; exit 1; fi

gen-secret/check-bin:
	jq --version foo >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
	yq --version foo >/dev/null 2>&1 || { echo >&2 "I require yq but it's not installed.  Aborting."; exit 1; }
	kubectl version foo >/dev/null 2>&1 || { echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }
	kubeseal --version foo >/dev/null 2>&1 || { echo >&2 "I require kubeseal but it's not installed.  Aborting."; exit 1; }

gen-secret/assert-tmp-dir:
	mkdir -p ./tmp

test-multiple:
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret1 SECRET_KEY=pass
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret2 SECRET_KEY=pass
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret3 SECRET_KEY=pass
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret4 SECRET_KEY=pass

re-encrypt-secret: gen-secret/check-bin gen-secret/assert-tmp-dir
	if test -z $(KUBE_MANIFEST) ; then echo "KUBE_MANIFEST not set"; exit 1; fi
	kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
		--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
		--re-encrypt < $(KUBE_MANIFEST) | yq . -y > tmp.yaml
	mv tmp.yaml $(KUBE_MANIFEST)

re-encrypt-multiple:
	make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret1-sealed.yaml
	make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret2-sealed.yaml
	make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret3-sealed.yaml
	make re-encrypt-secret KUBE_MANIFEST=./test-secrets/secret4-sealed.yaml

update-secret: gen-secret/check-bin gen-secret/assert-tmp-dir
	if test -z $(KUBE_MANIFEST) ; then echo "KUBE_MANIFEST not set"; exit 1; fi
	cat $(KUBE_MANIFEST)
