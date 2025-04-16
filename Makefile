# Image names
AUTH_IMAGE := auth:latest
BACKEND_IMAGE := backend:latest
ENVOY_IMAGE := envoy:latest

# Helm and Kubernetes
HELM_CHART := ./deploy
RELEASE_NAME := playground
NAMESPACE_OPS := ops
NAMESPACE_STG := stg

# --------------------------------------
# 🔧 Build & Load Docker Images to Minikube
# --------------------------------------
.PHONY: build-images load-images

build-images:
	docker build -t $(AUTH_IMAGE) ./services/auth
	docker build -t $(BACKEND_IMAGE) ./services/backend
	docker build -t $(ENVOY_IMAGE) ./services/envoy

load-images:
	minikube image load $(AUTH_IMAGE)
	minikube image load $(BACKEND_IMAGE)
	minikube image load $(ENVOY_IMAGE)

# --------------------------------------
# 🚀 Helm Install / Upgrade
# --------------------------------------
.PHONY: helm-install-stg helm-install-ops helm-upgrade-stg helm-upgrade-ops helm-uninstall

helm-install-ops: build-images load-images
	helm install $(RELEASE_NAME)-ops $(HELM_CHART) -f $(HELM_CHART)/values-ops.yaml --namespace $(NAMESPACE_OPS) --create-namespace

helm-install-stg: build-images load-images
	helm install $(RELEASE_NAME)-stg $(HELM_CHART) -f $(HELM_CHART)/values-stg.yaml --namespace $(NAMESPACE_STG) --create-namespace

helm-upgrade-ops: build-images load-images
	helm upgrade $(RELEASE_NAME)-ops $(HELM_CHART) -f $(HELM_CHART)/values-ops.yaml --namespace $(NAMESPACE_OPS)

helm-upgrade-stg: build-images load-images
	helm upgrade $(RELEASE_NAME)-stg $(HELM_CHART) -f $(HELM_CHART)/values-stg.yaml --namespace $(NAMESPACE_STG)

helm-uninstall:
	helm uninstall $(RELEASE_NAME)-ops --namespace $(NAMESPACE_OPS) || true
	helm uninstall $(RELEASE_NAME)-stg --namespace $(NAMESPACE_STG) || true

# --------------------------------------
# 🧪 Helm Dry-run Preview & Rollback
# --------------------------------------
.PHONY: helm-template-stg helm-template-ops helm-rollback-stg helm-rollback-ops

helm-template-stg:
	helm template $(RELEASE_NAME)-stg $(HELM_CHART) -f $(HELM_CHART)/values-stg.yaml

helm-template-ops:
	helm template $(RELEASE_NAME)-ops $(HELM_CHART) -f $(HELM_CHART)/values-ops.yaml

helm-rollback-stg:
	helm rollback $(RELEASE_NAME)-stg

helm-rollback-ops:
	helm rollback $(RELEASE_NAME)-ops

# --------------------------------------
# 🧹 Cleanup
# --------------------------------------
.PHONY: cleanup

cleanup: helm-uninstall remove-images

remove-images:
	@echo "Removing Docker images from local..."
	-docker rmi $(AUTH_IMAGE) $(BACKEND_IMAGE) $(ENVOY_IMAGE) 2>/dev/null || true
	@echo "Removing Docker images from Minikube..."
	-minikube ssh -- ctr -n k8s.io images rm docker.io/library/$(AUTH_IMAGE) || true
	-minikube ssh -- ctr -n k8s.io images rm docker.io/library/$(BACKEND_IMAGE) || true
	-minikube ssh -- ctr -n k8s.io images rm docker.io/library/$(ENVOY_IMAGE) || true
