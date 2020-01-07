PASSWORD_LENGTH = 32
SEALED_SECRETS_CONTROLLER_NAME=sealed-secrets
SEALED_SECRETS_CONTROLLER_NAMESPACE=sealed-secrets

gen-secret/uuid:
	uuidgen -r | tr -d '\n' > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-sealed-secret/uuid: gen-secret/uuid gen-kube-secret gen-sealed-secret

gen-sealed-secret/urandom: gen-secret/urandom gen-kube-secret gen-sealed-secret

gen-secret/urandom: gen-secret/check
	< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${PASSWORD_LENGTH} > ./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp

gen-kube-secret:
	kubectl -n $(NAMESPACE) create secret generic $(SECRET_NAME) --dry-run --from-file=$(SECRET_KEY)=./tmp/$(NAMESPACE)_$(SECRET_NAME).tmp -o json > ./tmp/$(SECRET_NAME).json

gen-sealed-secret:
	kubeseal --controller-name $(SEALED_SECRETS_CONTROLLER_NAME) \
		--controller-namespace $(SEALED_SECRETS_CONTROLLER_NAMESPACE) \
		 < ./tmp/$(SECRET_NAME).json > ./tmp/$(SECRET_NAME)-sealed.json
	echo "Copy to desired location"

gen-secret/check:
	if test -z $(NAMESPACE) ; then echo "NAMESPACE not set"; exit 1; fi
	if test -z $(SECRET_NAME) ; then echo "SECRET_NAME not set"; exit 1; fi
	if test -z $(SECRET_KEY) ; then echo "SECRET_KEY not set"; exit 1; fi
	mkdir -p ./tmp

test-multiple:
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret1 SECRET_KEY=pass
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret2 SECRET_KEY=pass
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret3 SECRET_KEY=pass
	make gen-sealed-secret/urandom NAMESPACE=blub SECRET_NAME=secret4 SECRET_KEY=pass
