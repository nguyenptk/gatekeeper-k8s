# 🛡️ gatekeeper-k8s

A modular Helm-powered Kubernetes stack, consisting of:

- **Envoy Gateway** – acting as an API gateway with routing, logging, and external authorization support.

- **Auth Service (Go)** – provides JWT-based login via REST and authorization via gRPC for Envoy's ext_authz filter.

- **Backend Service (Go)** – a protected microservice that sits behind Envoy and responds to public/private endpoints.

The Helm chart supports environment-based overrides (e.g., ops, stg) and can dynamically configure service names, ports, and Envoy upstreams through templated values.

---

## 📦 Structure

```
.
├── deploy/
│   ├── templates/
│   │   ├── auth/
│   │   ├── backend/
│   │   └── envoy/
│   ├── _helpers.tpl
│   ├── chart.yaml
│   ├── values.yaml
│   ├── values-stg.yaml
│   └── values-ops.yaml
├── scripts/
|   ├── test.sh
├── services/
│   ├── auth/
│   ├── backend/
│   └── envoy/
├── Makefile
└── README.md
```

---

## 🚀 1. Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Minikube](https://minikube.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)

Start Minikube:

```bash
minikube start
```

---

## 🛠️ 2. Build and Load Docker Images

```bash
make build-images
make load-images
```

This builds the `auth`, `backend`, and `envoy` images and loads them into Minikube’s Docker daemon.

---

## 📦 3. Install with Helm

### Ops environment:

```bash
make helm-install-ops
```

### Staging environment:

```bash
make helm-install-stg
```

---

## 🔁 4. Upgrade Chart with New Changes

```bash
make helm-upgrade-ops
make helm-upgrade-stg    
```

---

## 👀 5. Preview the Helm Template (Dry-run)

```bash
make helm-template-stg
make helm-template-ops
```

---

## 🧪 6. Run Tests

```bash
./test.sh
```

This script:
- Logs in to the auth service to fetch a JWT
- Calls `/public` without token
- Calls `/private` without and with token
- Prints all results

Make sure `minikube service envoy --url` is accessible and exported as the base URL.

---

## 🧹 7. Cleanup Resources

To uninstall Helm releases and delete Docker images from both local and Minikube:

```bash
make cleanup
```

This runs:
- `helm uninstall`
- `docker rmi` locally
- `minikube ssh -- ctr images rm ...`

---

## 🔄 8. Rollback (Optional)

Revert to a previous Helm release:

```bash
make helm-rollback-ops
make helm-rollback-stg
```

---

## 🔗 Testing

After deployment, port-forward `ops-envoy`:

```bash
kubectl port-forward svc/ops-envoy 8060:8060 -n ops
```

, or port-forward `stg-envoy`:

```bash
kubectl port-forward svc/ops-envoy 8060:8060 -n stg
```

Then run the test script:

```bash
./scripts/test.sh
```

---

## 🧾 Notes

- Envoy config is generated from a Helm `ConfigMap`
- Auth and backend service names are dynamically set per environment via `values-stg.yaml` and `values-ops.yaml`
- You can extend the Makefile and values files to support additional environments

---