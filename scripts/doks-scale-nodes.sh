#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_DIR="$REPO_ROOT/k8s/overlays/doks"
DEPLOY_ENV_FILE="${DOKS_ENV_FILE:-$OVERLAY_DIR/deploy.env}"

TARGET_COUNT="${1:-}"
DOKS_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-}"
DOKS_NODE_POOL_NAME="${DOKS_NODE_POOL_NAME:-}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/doks-scale-nodes.sh <target-count> [node-pool-name]

Examples:
  ./scripts/doks-scale-nodes.sh 2
  ./scripts/doks-scale-nodes.sh 3 pool-2h5y79uc1

Environment:
  DOKS_ENV_FILE        Optional path to a deploy.env file.
  DOKS_CLUSTER_NAME    Cluster name or ID. Loaded from deploy.env if present.
  DOKS_NODE_POOL_NAME  Optional node pool name. Loaded from deploy.env if present.
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

  echo "[doks-scale-nodes] loading deployment variables from '$file_path'"
  set -a
  # shellcheck disable=SC1090
  source "$file_path"
  set +a

  DOKS_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-}"
  DOKS_NODE_POOL_NAME="${DOKS_NODE_POOL_NAME:-}"
}

validate_target_count() {
  if [[ -z "$TARGET_COUNT" ]]; then
    usage >&2
    exit 1
  fi

  if ! [[ "$TARGET_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Target count must be a positive integer. Received: $TARGET_COUNT" >&2
    exit 1
  fi
}

resolve_node_pool_name() {
  if [[ -n "$DOKS_NODE_POOL_NAME" ]]; then
    printf '%s\n' "$DOKS_NODE_POOL_NAME"
    return 0
  fi

  doctl kubernetes cluster node-pool list "$DOKS_CLUSTER_NAME" | awk 'NR==2 {print $2}'
}

current_node_pool_count() {
  local pool_name="$1"

  doctl kubernetes cluster node-pool list "$DOKS_CLUSTER_NAME" | awk -v pool="$pool_name" '$2 == pool {print $4}'
}

echo "[doks-scale-nodes] checking required tools"
require_command doctl

load_env_file "$DEPLOY_ENV_FILE"
validate_target_count

if [[ -n "${2:-}" ]]; then
  DOKS_NODE_POOL_NAME="$2"
fi

if [[ -z "$DOKS_CLUSTER_NAME" ]]; then
  echo "Missing required deployment variable: DOKS_CLUSTER_NAME" >&2
  exit 1
fi

RESOLVED_NODE_POOL_NAME="$(resolve_node_pool_name)"

if [[ -z "$RESOLVED_NODE_POOL_NAME" ]]; then
  echo "Could not determine a node pool for cluster '$DOKS_CLUSTER_NAME'" >&2
  exit 1
fi

CURRENT_COUNT="$(current_node_pool_count "$RESOLVED_NODE_POOL_NAME")"

if [[ -z "$CURRENT_COUNT" ]]; then
  echo "Could not determine the current node count for pool '$RESOLVED_NODE_POOL_NAME'" >&2
  exit 1
fi

echo "[doks-scale-nodes] cluster: $DOKS_CLUSTER_NAME"
echo "[doks-scale-nodes] node pool: $RESOLVED_NODE_POOL_NAME"
echo "[doks-scale-nodes] current node count: $CURRENT_COUNT"
echo "[doks-scale-nodes] target node count: $TARGET_COUNT"

doctl kubernetes cluster node-pool update "$DOKS_CLUSTER_NAME" "$RESOLVED_NODE_POOL_NAME" --count "$TARGET_COUNT"

echo "[doks-scale-nodes] scale request submitted successfully"
echo "[doks-scale-nodes] updated node pool status:"
doctl kubernetes cluster node-pool get "$DOKS_CLUSTER_NAME" "$RESOLVED_NODE_POOL_NAME"