CHART_REPO := "https://prometheus-community.github.io/helm-charts"
CHART_REPO_NAME := prometheus-community
CHART_NAME := kube-prometheus-stack

ifndef ENVIRONMENT
	ENVIRONMENT := dev
endif

render:
	helm repo add $(CHART_REPO_NAME) $(CHART_REPO)
	helm template kube-prometheus-stack $(CHART_REPO_NAME)/$(CHART_NAME) --namespace monitoring --values values.yaml > base/all.yaml
deploy: render
	kustomize build $(ENVIRONMENT) | kubectl apply -f -

deploy-crds:
	kustomize build crds | kubectl apply -f -
