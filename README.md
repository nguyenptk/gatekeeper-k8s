# gatekeeper-k8s

A lightweight setup that uses **Envoy as both an API Gateway and Kubernetes Ingress Controller** in front of two small Go services — one for login/auth (with gRPC for Envoy’s external authorization) and one for a backend with public/private routes. Everything runs on Kubernetes using Helm.

This project started as a playground for testing service-to-service authentication, and route protection — and then grew into a reusable, multi-environment chart you can install with a single `make` command.

---

## What’s in the box

- **Envoy** – serves as the Ingress Controller and API gateway, handling routing, load‑balancing, logging, and calling the auth service for token validation (via gRPC)  
- **Auth (Go)** – REST endpoint for `/login`, gRPC endpoint for Envoy ext_authz, issues JWTs, and `/healthcheck` for probes
- **Backend (Go)** – public `/public`, protected `/private`, and `/healthcheck` for probes
- **Helm chart** – one chart for all services, with values for `ops` and `stg` environments
- **Makefile** – to help typing Helm commands repeatedly

## Structure

```
.
├── deploy
│   ├── charts
│   │   ├── auth
│   │   ├── backend
│   │   ├── envoy
│   ├── Chart.lock
│   ├── Chart.yaml
│   └── values.yaml
├── scripts
│   └── test.sh
├── services
│   ├── auth
│   │   ├── Dockerfile
│   │   └── main.go
│   ├── backend
│   │   ├── Dockerfile
│   │   └── main.go
│   └── envoy
│       ├── Dockerfile
│       └── envoy.yaml
├── Makefile
└── README.md
```

---

## 1. Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)

Start Minikube:

```bash
minikube start
```

---

## 2. Build and Load Docker Images

```bash
make build-images
make load-images
```

This builds the `auth`, `backend`, and `envoy` images and loads them into Minikube’s Docker daemon.

---

## 3. Install with Helm

### Ops environment:

```bash
make helm-install-ops
```

### Staging environment:

```bash
make helm-install-stg
```

---

## 4. Test the Helm Template

```bash
make helm-test-ops
make helm-test-stg
```

---

## 5. Preview the Helm Template (Dry-run)

```bash
make helm-template-ops
make helm-template-stg
```

---

## 6. Run Tests

### 6.1. Test the system with `curl`

After deployment, the `LoadBalancer` will route the downstream's requests to all `envoy` pods.

Port-forward `ops-envoy`:

```bash
kubectl port-forward deployment/ops-envoy 8060:8060 -n ops
```

or port-forward `stg-envoy`:

```bash
kubectl port-forward deployment/stg-envoy 8060:8060 -n stg
```

Then run the test script:

```bash
./scripts/test.sh
```

This script:
- calls `/` endpoint to get the landing page information
- calls `/login` endpoint to the auth service to fetch a JWT token
- calls `/public` endpoint without token
- calls `/private` endpoint without and with token
- prints results; Envoy will round‑robin across auth & backend pods.

Further, we can collect the Envoy gateway's stats:

```bash
kubectl port-forward deployment/ops-envoy 9901:9901 -n ops
```

and call admin's endpoint:

```bash
curl http://localhost:9901/stats
```

Here are some samples of the stats:
```
cluster.auth_http.upstream_rq_200: 5
cluster.backend_service.upstream_rq_200: 10
cluster.auth_ext.internal.upstream_rq_time: P0(nan,0) P25(nan,0) P50(nan,0) P75(nan,0) P90(nan,0) P95(nan,1.05) P99(nan,1.09) P99.5(nan,1.095) P99.9(nan,1.099) P100(nan,1.1)
```

### 6.2. Smoke Tests

Quick “on/off” tests to verify each sub‑chart’s `enabled` flag works as expected.

```bash
make helm-smoke-noauth
```

Verify only backend service & envoy are running

```bash
kubectl get deployments -n smoke-test
```

Clean up the smoke tests

```bash
make cleanup-smoke
```

---

## 7. Upgrade Chart with New Changes

```bash
make helm-upgrade-ops
make helm-upgrade-stg    
```

---

## 8. Cleanup Resources

To uninstall Helm releases and delete Docker images from both local and Minikube:

```bash
make cleanup
```

This runs:
- `helm uninstall`
- `docker rmi` locally
- `minikube ssh -- ctr images rm ...`

---

## 9. Rollback (Optional)

Revert to a previous Helm release:

```bash
make helm-rollback-ops
make helm-rollback-stg
```

---

## Notes

- Envoy config is generated from a Helm `ConfigMap`
- Auth and backend service names are dynamically set per environment via `values.stg.yaml` and `values.ops.yaml`

---