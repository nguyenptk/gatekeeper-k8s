AUTH_IMAGE    := auth:latest
BACKEND_IMAGE := backend:latest
ENVOY_IMAGE   := envoy:latest

HELM_CHART    := ./deploy
RELEASE_NAME  := playground
NAMESPACE_OPS := ops
NAMESPACE_STG := stg

# Build & Load Docker Images into Minikube
.PHONY: build-images load-images
build-images:
	docker build -t $(AUTH_IMAGE)    ./services/auth
	docker build -t $(BACKEND_IMAGE) ./services/backend
	docker build -t $(ENVOY_IMAGE)   ./services/envoy

load-images:
	minikube image load $(AUTH_IMAGE)
	minikube image load $(BACKEND_IMAGE)
	minikube image load $(ENVOY_IMAGE)

# Helm Dependencies
.PHONY: helm-deps
helm-deps:
	@echo "🔄 Updating chart dependencies (if any)..."
	helm dependency update $(HELM_CHART) || true

# Helm Install / Upgrade
.PHONY: helm-install-ops helm-install-stg helm-upgrade-ops helm-upgrade-stg

helm-install-ops: build-images load-images helm-deps
	helm install $(RELEASE_NAME)-ops $(HELM_CHART) \
	  -f $(HELM_CHART)/values.ops.yaml \
	  --namespace $(NAMESPACE_OPS) --create-namespace

helm-upgrade-ops: build-images load-images helm-deps
	helm upgrade $(RELEASE_NAME)-ops $(HELM_CHART) \
	  -f $(HELM_CHART)/values.ops.yaml \
	  --namespace $(NAMESPACE_OPS)

helm-install-stg: build-images load-images helm-deps
	helm install $(RELEASE_NAME)-stg $(HELM_CHART) \
	  -f $(HELM_CHART)/values.stg.yaml \
	  --namespace $(NAMESPACE_STG) --create-namespace

helm-upgrade-stg: build-images load-images helm-deps
	helm upgrade $(RELEASE_NAME)-stg $(HELM_CHART) \
	  -f $(HELM_CHART)/values.stg.yaml \
	  --namespace $(NAMESPACE_STG)

# Helm Uninstall
helm-uninstall:
	helm uninstall $(RELEASE_NAME)-ops --namespace $(NAMESPACE_OPS) || true
	helm uninstall $(RELEASE_NAME)-stg --namespace $(NAMESPACE_STG) || true

# Helm Dry-run & Rollback
.PHONY: helm-template-ops helm-template-stg helm-rollback-ops helm-rollback-stg

helm-template-ops:
	helm template $(RELEASE_NAME)-ops $(HELM_CHART) \
	  -f $(HELM_CHART)/values.ops.yaml

helm-template-stg:
	helm template $(RELEASE_NAME)-stg $(HELM_CHART) \
	  -f $(HELM_CHART)/values.stg.yaml

helm-rollback-ops:
	helm rollback $(RELEASE_NAME)-ops

helm-rollback-stg:
	helm rollback $(RELEASE_NAME)-stg

# Helm Test
.PHONY: helm-test-ops helm-test-stg

helm-test-ops:
	helm test $(RELEASE_NAME)-ops -n $(NAMESPACE_OPS)

helm-test-stg:
	helm test $(RELEASE_NAME)-stg -n $(NAMESPACE_STG)

# Helm Smoke
.PHONY: helm-smoke-noauth helm-smoke-nobackend

helm-smoke-noauth:
	helm install smoke-noauth $(HELM_CHART) \
	  --namespace smoke-test --create-namespace \
	  --set auth.enabled=false \
	  --set backend.enabled=true \
	  --set envoy.enabled=true \
	  -f deploy/values.yaml

helm-smoke-nobackend:
	helm install smoke-nobackend $(HELM_CHART) \
	  --namespace smoke-test --create-namespace \
	  --set auth.enabled=true \
	  --set backend.enabled=false \
	  --set envoy.enabled=true \
	  -f deploy/values.yaml

# Cleanup
.PHONY: cleanup remove-images

cleanup: helm-uninstall remove-images

remove-images:
	@echo "Removing local Docker images…"
	- docker rmi $(AUTH_IMAGE) $(BACKEND_IMAGE) $(ENVOY_IMAGE) 2>/dev/null || true
	@echo "Removing images from Minikube…"
	- minikube image rm $(AUTH_IMAGE)  || true
	- minikube image rm $(BACKEND_IMAGE) || true
	- minikube image rm $(ENVOY_IMAGE)   || true

# Cleanup Smoke
.PHONY: cleanup-smoke

cleanup-smoke:
	helm uninstall smoke-noauth --namespace smoke-test || true
	helm uninstall smoke-nobackend --namespace smoke-test || true
	kubectl delete ns smoke-test
