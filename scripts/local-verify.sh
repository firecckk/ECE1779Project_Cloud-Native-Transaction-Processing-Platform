#!/usr/bin/env bash

set -euo pipefail

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
NAMESPACE="${NAMESPACE:-transaction-platform}"
VERIFY_RETRIES="${VERIFY_RETRIES:-20}"
VERIFY_SLEEP_SECONDS="${VERIFY_SLEEP_SECONDS:-3}"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

fetch_with_retries() {
  local url="$1"
  local response=""
  local attempt=1

  while (( attempt <= VERIFY_RETRIES )); do
    if response="$(curl -fsS "$url" 2>/dev/null)"; then
      printf '%s\n' "$response"
      return 0
    fi

    sleep "$VERIFY_SLEEP_SECONDS"
    ((attempt++))
  done

  echo "Failed to reach URL after ${VERIFY_RETRIES} attempts: $url" >&2
  return 1
}

echo "[local-verify] checking required tools"
require_command kubectl
require_command minikube
require_command curl

echo "[local-verify] ensuring deployments are ready"
kubectl rollout status deployment/transaction-postgres -n "$NAMESPACE" --timeout=180s >/dev/null
kubectl rollout status deployment/transaction-backend -n "$NAMESPACE" --timeout=180s >/dev/null

SERVICE_URL="$(minikube service transaction-backend -n "$NAMESPACE" -p "$MINIKUBE_PROFILE" --url)"

echo "[local-verify] backend url: $SERVICE_URL"

HEALTH_RESPONSE="$(fetch_with_retries "$SERVICE_URL/health")"
REPORT_RESPONSE="$(fetch_with_retries "$SERVICE_URL/reports/merchant-ranking?limit=5")"

if [[ "$HEALTH_RESPONSE" != *'"status":"ok"'* ]]; then
  echo "[local-verify] unexpected health response: $HEALTH_RESPONSE" >&2
  exit 1
fi

if [[ "$REPORT_RESPONSE" != *'"rows":'* ]]; then
  echo "[local-verify] unexpected report response: $REPORT_RESPONSE" >&2
  exit 1
fi

echo "[local-verify] health response: $HEALTH_RESPONSE"
echo "[local-verify] report response: $REPORT_RESPONSE"
echo "[local-verify] verification finished successfully"