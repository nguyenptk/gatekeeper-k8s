#!/usr/bin/env bash
set -euo pipefail

URL="${URL:-http://localhost:8060}"      # Envoy gateway URL
NAMESPACE="${NAMESPACE:-ops}"            # Kubernetes namespace for HPA check

# Performance test parameters
PERF_DURATION="${PERF_DURATION:-60}"
PERF_CONCURRENCY="${PERF_CONCURRENCY:-100}"
PERF_REQUESTS="${PERF_REQUESTS:-1000}"
SAMPLE_INTERVAL="${SAMPLE_INTERVAL:-10}"
SAMPLES=$(( PERF_DURATION / SAMPLE_INTERVAL ))

divider() {
  printf "\n\n"
}

generate_load() {
  for i in $(seq 1 "$PERF_REQUESTS"); do
    curl -s "$URL/public" >/dev/null &
    if (( i % PERF_CONCURRENCY == 0 )); then
      wait
    fi
  done
  wait
}

# 1. Functional Test
functional_test() {
  echo "🔹 Gateway URL: $URL"
  divider

  echo "1) GET /"
  curl -s -w "\nHTTP/1.1 %{http_code}\n" "$URL/"
  divider

  echo "2) POST /login to fetch JWT Token"
  TOKEN="$(curl -s -X POST "$URL/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"user","password":"password"}' \
    | jq -r '.token')"
  echo "JWT Token: $TOKEN"
  divider

  echo "3) GET /public (no token)"
  curl -s -w "\nHTTP/1.1 %{http_code}\n" "$URL/public"
  divider

  echo "4) GET /private (no token)"
  curl -s -w "\nHTTP/1.1 %{http_code}\n" "$URL/private"
  divider

  echo "5) GET /private (with token)"
  curl -s -H "Authorization: Bearer $TOKEN" \
       -w "\nHTTP/1.1 %{http_code}\n" \
       "$URL/private"
  divider

  echo "✅ Functional test complete."
}

# 2. Performance Test (trigger HPA)
perf_test() {
  divider
  echo "Current HPA status at $(date +'%T'):"
  kubectl get hpa -n "$NAMESPACE"
  divider

  echo "🚀 Starting continuous load for ${PERF_DURATION}s (concurrency=${PERF_CONCURRENCY}, requests=${PERF_REQUESTS})"
  divider

  generate_load &
  LOAD_PID=$!
  echo "Load generator PID: $LOAD_PID"
  divider

  sleep "$PERF_DURATION"

  kill "$LOAD_PID" 2>/dev/null || true
  echo "✔ Load stopped"
  divider

  echo "Sampling HPA & pods every ${SAMPLE_INTERVAL}s for ${PERF_DURATION}s"
  SAMPLE_COUNT=$(( PERF_DURATION / SAMPLE_INTERVAL ))
  for i in $(seq 1 "$SAMPLE_COUNT"); do
    echo "→ [$(date +'%T')] Sample $i/$SAMPLE_COUNT"
    kubectl get hpa -n "$NAMESPACE"
    kubectl get pods -n "$NAMESPACE"
    divider
    sleep "$SAMPLE_INTERVAL"
  done

  echo "✅ Performance test complete."
  divider
}

# Main entrypoint
case "${1:-all}" in
  functional)
    functional_test
    ;;
  perf)
    perf_test
    ;;
  all)
    functional_test
    perf_test
    ;;
  *)
    echo "Usage: $0 {functional|perf|all}"
    exit 1
    ;;
esac