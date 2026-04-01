#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-transaction-platform}"
VERIFY_RETRIES="${VERIFY_RETRIES:-20}"
VERIFY_SLEEP_SECONDS="${VERIFY_SLEEP_SECONDS:-5}"
BASE_URL="${BASE_URL:-${1:-}}"

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

discover_service_url() {
  local endpoint=""

  endpoint="$(kubectl get svc transaction-frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

  if [[ -z "$endpoint" ]]; then
    endpoint="$(kubectl get svc transaction-frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  fi

  if [[ -z "$endpoint" ]]; then
    echo "Could not determine transaction-frontend LoadBalancer endpoint in namespace '$NAMESPACE'" >&2
    return 1
  fi

  printf 'http://%s\n' "$endpoint"
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

echo "[doks-verify] checking required tools"
require_command kubectl
require_command curl

if [[ -z "$BASE_URL" ]]; then
  echo "[doks-verify] discovering frontend LoadBalancer endpoint"
  BASE_URL="$(discover_service_url)"
fi

echo "[doks-verify] frontend url: $BASE_URL"

HEALTH_RESPONSE="$(fetch_with_retries "$BASE_URL/health")"
REPORT_RESPONSE="$(fetch_with_retries "$BASE_URL/api/reports/merchant-ranking?limit=5")"

if [[ "$HEALTH_RESPONSE" != *'"status":"ok"'* ]]; then
  echo "[doks-verify] unexpected health response: $HEALTH_RESPONSE" >&2
  exit 1
fi

if [[ "$REPORT_RESPONSE" != *'"rows":'* ]]; then
  echo "[doks-verify] unexpected report response: $REPORT_RESPONSE" >&2
  exit 1
fi

echo "[doks-verify] health response: $HEALTH_RESPONSE"
echo "[doks-verify] report response: $REPORT_RESPONSE"
echo "[doks-verify] verification finished successfully"