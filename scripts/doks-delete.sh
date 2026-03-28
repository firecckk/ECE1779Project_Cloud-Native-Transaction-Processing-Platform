#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_DIR="$REPO_ROOT/k8s/overlays/doks"
DEPLOY_ENV_FILE="${DOKS_ENV_FILE:-$OVERLAY_DIR/deploy.env}"

TARGET_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-${1:-}}"
DELETE_ASSOCIATED_RESOURCES="${DELETE_ASSOCIATED_RESOURCES:-1}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/doks-delete.sh [cluster-name]

Examples:
  ./scripts/doks-delete.sh
  ./scripts/doks-delete.sh transaction-platform

Environment:
  DOKS_ENV_FILE                Optional path to a deploy.env file.
  DOKS_CLUSTER_NAME            Cluster name or ID. Loaded from deploy.env if present.
  DELETE_ASSOCIATED_RESOURCES  Set to 0 to keep load balancers, volumes, and snapshots.
EOF
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

load_env_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  echo "[doks-delete] loading deployment variables from '$file_path'"
  set -a
  # shellcheck disable=SC1090
  source "$file_path"
  set +a

  TARGET_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-${TARGET_CLUSTER_NAME:-}}"
}

cluster_exists() {
  doctl kubernetes cluster get "$TARGET_CLUSTER_NAME" >/dev/null 2>&1
}

echo "[doks-delete] checking required tools"
require_command doctl

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

load_env_file "$DEPLOY_ENV_FILE"

if [[ -z "$TARGET_CLUSTER_NAME" ]]; then
  echo "Missing required deployment variable: DOKS_CLUSTER_NAME" >&2
  usage >&2
  exit 1
fi

if ! cluster_exists; then
  echo "[doks-delete] cluster '$TARGET_CLUSTER_NAME' was not found; nothing to delete"
  exit 0
fi

DELETE_ARGS=(--force)

if [[ "$DELETE_ASSOCIATED_RESOURCES" == "1" ]]; then
  DELETE_ARGS+=(--dangerous)
fi

echo "[doks-delete] deleting cluster '$TARGET_CLUSTER_NAME'"

if [[ "$DELETE_ASSOCIATED_RESOURCES" == "1" ]]; then
  echo "[doks-delete] associated load balancers, volumes, and snapshots will also be deleted"
fi

doctl kubernetes cluster delete "$TARGET_CLUSTER_NAME" "${DELETE_ARGS[@]}"

echo "[doks-delete] deletion request finished successfully"
