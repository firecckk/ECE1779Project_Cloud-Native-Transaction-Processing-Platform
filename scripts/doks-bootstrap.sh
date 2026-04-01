#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_DIR="$REPO_ROOT/k8s/overlays/doks"
DEPLOY_ENV_FILE="${DOKS_ENV_FILE:-$OVERLAY_DIR/deploy.env}"
CONFIG_ENV_FILE="${DOKS_CONFIG_FILE:-$OVERLAY_DIR/config.env}"
SECRETS_ENV_FILE="${DOKS_SECRETS_FILE:-$OVERLAY_DIR/secrets.env}"

DOKS_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-}"
DOKR_REGISTRY_NAME="${DOKR_REGISTRY_NAME:-}"
NAMESPACE="${NAMESPACE:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOKS_REGION="${DOKS_REGION:-tor1}"
DOKS_NODE_SIZE="${DOKS_NODE_SIZE:-s-1vcpu-2gb}"
DOKS_NODE_COUNT="${DOKS_NODE_COUNT:-1}"
DOKS_NODE_POOL_NAME="${DOKS_NODE_POOL_NAME:-transaction-platform-default-pool}"
DOKS_AUTO_SCALE="${DOKS_AUTO_SCALE:-true}"
DOKS_MIN_NODES="${DOKS_MIN_NODES:-1}"
DOKS_MAX_NODES="${DOKS_MAX_NODES:-3}"
DOKS_K8S_VERSION="${DOKS_K8S_VERSION:-latest}"

SYNC_GITHUB_CD="${SYNC_GITHUB_CD:-0}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
DIGITALOCEAN_ACCESS_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN:-}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/doks-bootstrap.sh

What it does:
  - creates a DOKS cluster if it does not already exist
  - creates a DigitalOcean Container Registry if it does not already exist
  - writes a canonical k8s/overlays/doks/deploy.env file
  - creates local config.env and secrets.env from examples if they are missing
  - saves kubeconfig for the cluster

Optional environment variables:
  DOKS_CLUSTER_NAME         Default: transaction-platform
  DOKR_REGISTRY_NAME        Default: transaction-platform
  NAMESPACE                 Default: transaction-platform
  IMAGE_TAG                 Default: latest
  DOKS_REGION               Default: tor1
  DOKS_NODE_SIZE            Default: s-1vcpu-2gb
  DOKS_NODE_COUNT           Default: 1
  DOKS_NODE_POOL_NAME       Default: transaction-platform-default-pool
  DOKS_AUTO_SCALE           Default: true
  DOKS_MIN_NODES            Default: 1
  DOKS_MAX_NODES            Default: 3
  DOKS_K8S_VERSION          Default: latest
  DOKS_ENV_FILE             Optional alternate deploy.env path
  DOKS_CONFIG_FILE          Optional alternate config.env path
  DOKS_SECRETS_FILE         Optional alternate secrets.env path
  SYNC_GITHUB_CD            Set to 1 to also sync GitHub repo variables and secrets
  GITHUB_REPOSITORY         Required when SYNC_GITHUB_CD=1, format owner/repo
  DIGITALOCEAN_ACCESS_TOKEN Required when SYNC_GITHUB_CD=1

Examples:
  ./scripts/doks-bootstrap.sh
  DOKS_CLUSTER_NAME=my-cluster DOKR_REGISTRY_NAME=my-registry ./scripts/doks-bootstrap.sh
  SYNC_GITHUB_CD=1 GITHUB_REPOSITORY=owner/repo DIGITALOCEAN_ACCESS_TOKEN=... ./scripts/doks-bootstrap.sh
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

  echo "[doks-bootstrap] loading deployment variables from '$file_path'"
  set -a
  # shellcheck disable=SC1090
  source "$file_path"
  set +a
}

apply_defaults() {
  DOKS_CLUSTER_NAME="${DOKS_CLUSTER_NAME:-transaction-platform}"
  DOKR_REGISTRY_NAME="${DOKR_REGISTRY_NAME:-transaction-platform}"
  NAMESPACE="${NAMESPACE:-transaction-platform}"
  IMAGE_TAG="${IMAGE_TAG:-latest}"
  DOKS_REGION="${DOKS_REGION:-tor1}"
  DOKS_NODE_SIZE="${DOKS_NODE_SIZE:-s-1vcpu-2gb}"
  DOKS_NODE_COUNT="${DOKS_NODE_COUNT:-1}"
  DOKS_NODE_POOL_NAME="${DOKS_NODE_POOL_NAME:-transaction-platform-default-pool}"
  DOKS_AUTO_SCALE="${DOKS_AUTO_SCALE:-true}"
  DOKS_MIN_NODES="${DOKS_MIN_NODES:-1}"
  DOKS_MAX_NODES="${DOKS_MAX_NODES:-3}"
  DOKS_K8S_VERSION="${DOKS_K8S_VERSION:-latest}"
}

validate_autoscaling_config() {
  if ! [[ "$DOKS_NODE_COUNT" =~ ^[0-9]+$ && "$DOKS_MIN_NODES" =~ ^[0-9]+$ && "$DOKS_MAX_NODES" =~ ^[0-9]+$ ]]; then
    echo "DOKS_NODE_COUNT, DOKS_MIN_NODES, and DOKS_MAX_NODES must be non-negative integers" >&2
    exit 1
  fi

  if [[ "$DOKS_AUTO_SCALE" != "true" && "$DOKS_AUTO_SCALE" != "false" ]]; then
    echo "DOKS_AUTO_SCALE must be either 'true' or 'false'" >&2
    exit 1
  fi

  if (( DOKS_MIN_NODES > DOKS_MAX_NODES )); then
    echo "DOKS_MIN_NODES cannot be greater than DOKS_MAX_NODES" >&2
    exit 1
  fi

  if [[ "$DOKS_AUTO_SCALE" == "true" ]]; then
    if (( DOKS_NODE_COUNT < DOKS_MIN_NODES || DOKS_NODE_COUNT > DOKS_MAX_NODES )); then
      echo "When autoscaling is enabled, DOKS_NODE_COUNT must be between DOKS_MIN_NODES and DOKS_MAX_NODES" >&2
      exit 1
    fi
  fi
}

cluster_exists() {
  doctl kubernetes cluster get "$DOKS_CLUSTER_NAME" >/dev/null 2>&1
}

registry_exists() {
  doctl registry get "$DOKR_REGISTRY_NAME" >/dev/null 2>&1
}

cluster_status() {
  doctl kubernetes cluster list --format Name,Status --no-header | awk -v name="$DOKS_CLUSTER_NAME" '$1 == name {print $2}'
}

wait_for_cluster_ready() {
  local attempt=1
  local status=""

  while (( attempt <= 60 )); do
    status="$(cluster_status || true)"

    if [[ "$status" == "running" ]]; then
      echo "[doks-bootstrap] cluster '$DOKS_CLUSTER_NAME' is running"
      return 0
    fi

    echo "[doks-bootstrap] waiting for cluster '$DOKS_CLUSTER_NAME' to become ready (status: ${status:-unknown})"
    sleep 20
    ((attempt++))
  done

  echo "Timed out waiting for cluster '$DOKS_CLUSTER_NAME' to become ready" >&2
  return 1
}

ensure_overlay_env_files() {
  if [[ ! -f "$CONFIG_ENV_FILE" ]]; then
    echo "[doks-bootstrap] creating '$CONFIG_ENV_FILE' from example"
    cp "$OVERLAY_DIR/config.env.example" "$CONFIG_ENV_FILE"
  fi

  if [[ ! -f "$SECRETS_ENV_FILE" ]]; then
    echo "[doks-bootstrap] creating '$SECRETS_ENV_FILE' from example"
    cp "$OVERLAY_DIR/secrets.env.example" "$SECRETS_ENV_FILE"
  fi
}

write_deploy_env() {
  cat > "$DEPLOY_ENV_FILE" <<EOF
# DigitalOcean deployment variables used by scripts/doks-deploy.sh.
# Generated by scripts/doks-bootstrap.sh.

DOKS_CLUSTER_NAME=$DOKS_CLUSTER_NAME
DOKR_REGISTRY_NAME=$DOKR_REGISTRY_NAME
IMAGE_TAG=$IMAGE_TAG
NAMESPACE=$NAMESPACE
DOKS_REGION=$DOKS_REGION
DOKS_NODE_SIZE=$DOKS_NODE_SIZE
DOKS_NODE_COUNT=$DOKS_NODE_COUNT
DOKS_NODE_POOL_NAME=$DOKS_NODE_POOL_NAME
DOKS_AUTO_SCALE=$DOKS_AUTO_SCALE
DOKS_MIN_NODES=$DOKS_MIN_NODES
DOKS_MAX_NODES=$DOKS_MAX_NODES
DOKS_K8S_VERSION=$DOKS_K8S_VERSION
EOF
}

sync_github_cd() {
  if [[ "$SYNC_GITHUB_CD" != "1" ]]; then
    return 0
  fi

  require_command gh

  if [[ -z "$GITHUB_REPOSITORY" ]]; then
    echo "GITHUB_REPOSITORY is required when SYNC_GITHUB_CD=1" >&2
    exit 1
  fi

  if [[ -z "$DIGITALOCEAN_ACCESS_TOKEN" ]]; then
    echo "DIGITALOCEAN_ACCESS_TOKEN is required when SYNC_GITHUB_CD=1" >&2
    exit 1
  fi

  echo "[doks-bootstrap] syncing GitHub repository variables"
  gh variable set DOKS_CLUSTER_NAME --repo "$GITHUB_REPOSITORY" --body "$DOKS_CLUSTER_NAME"
  gh variable set DOKR_REGISTRY_NAME --repo "$GITHUB_REPOSITORY" --body "$DOKR_REGISTRY_NAME"
  gh variable set K8S_NAMESPACE --repo "$GITHUB_REPOSITORY" --body "$NAMESPACE"

  echo "[doks-bootstrap] syncing GitHub repository secrets"
  printf '%s' "$DIGITALOCEAN_ACCESS_TOKEN" | gh secret set DIGITALOCEAN_ACCESS_TOKEN --repo "$GITHUB_REPOSITORY"
  gh secret set DOKS_CONFIG_ENV --repo "$GITHUB_REPOSITORY" < "$CONFIG_ENV_FILE"
  gh secret set DOKS_SECRETS_ENV --repo "$GITHUB_REPOSITORY" < "$SECRETS_ENV_FILE"
}

echo "[doks-bootstrap] checking required tools"
require_command doctl
require_command kubectl

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

load_env_file "$DEPLOY_ENV_FILE"
apply_defaults
validate_autoscaling_config
ensure_overlay_env_files

if ! registry_exists; then
  echo "[doks-bootstrap] creating registry '$DOKR_REGISTRY_NAME'"
  doctl registry create "$DOKR_REGISTRY_NAME"
else
  echo "[doks-bootstrap] registry '$DOKR_REGISTRY_NAME' already exists"
fi

if ! cluster_exists; then
  echo "[doks-bootstrap] creating cluster '$DOKS_CLUSTER_NAME'"
  doctl kubernetes cluster create "$DOKS_CLUSTER_NAME" \
    --region "$DOKS_REGION" \
    --version "$DOKS_K8S_VERSION" \
    --node-pool "name=$DOKS_NODE_POOL_NAME;size=$DOKS_NODE_SIZE;count=$DOKS_NODE_COUNT;auto-scale=$DOKS_AUTO_SCALE;min-nodes=$DOKS_MIN_NODES;max-nodes=$DOKS_MAX_NODES"
else
  echo "[doks-bootstrap] cluster '$DOKS_CLUSTER_NAME' already exists"
fi

wait_for_cluster_ready

echo "[doks-bootstrap] saving kubeconfig for cluster '$DOKS_CLUSTER_NAME'"
doctl kubernetes cluster kubeconfig save "$DOKS_CLUSTER_NAME"

write_deploy_env
sync_github_cd

echo "[doks-bootstrap] bootstrap finished successfully"
echo "[doks-bootstrap] cluster: $DOKS_CLUSTER_NAME"
echo "[doks-bootstrap] registry: $DOKR_REGISTRY_NAME"
echo "[doks-bootstrap] deploy env: $DEPLOY_ENV_FILE"
echo "[doks-bootstrap] config env: $CONFIG_ENV_FILE"
echo "[doks-bootstrap] secrets env: $SECRETS_ENV_FILE"