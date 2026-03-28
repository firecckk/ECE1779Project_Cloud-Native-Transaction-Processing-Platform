#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-transaction-platform}"
ALL_NAMESPACES=0
TARGET_NODE=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/pod-node-distribution.sh [options]

Options:
  -n, --namespace <namespace>  Namespace to inspect. Default: transaction-platform
  -A, --all-namespaces         Inspect pods across all namespaces.
      --node <node-name>       Show only pods scheduled on a specific node.
  -h, --help                   Show this help message.

Examples:
  ./scripts/pod-node-distribution.sh
  ./scripts/pod-node-distribution.sh -n kube-system
  ./scripts/pod-node-distribution.sh -A
  ./scripts/pod-node-distribution.sh --node transaction-platform-default-pool-xxxx
EOF
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--namespace)
        if [[ -z "${2:-}" ]]; then
          echo "Missing value for $1" >&2
          usage >&2
          exit 1
        fi
        NAMESPACE="$2"
        shift 2
        ;;
      -A|--all-namespaces)
        ALL_NAMESPACES=1
        shift
        ;;
      --node)
        if [[ -z "${2:-}" ]]; then
          echo "Missing value for $1" >&2
          usage >&2
          exit 1
        fi
        TARGET_NODE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

build_kubectl_args() {
  local -n out_ref=$1
  out_ref=(get pods)

  if [[ "$ALL_NAMESPACES" -eq 1 ]]; then
    out_ref+=( -A )
  else
    out_ref+=( -n "$NAMESPACE" )
  fi

  if [[ -n "$TARGET_NODE" ]]; then
    out_ref+=( --field-selector "spec.nodeName=$TARGET_NODE" )
  fi

  out_ref+=( -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP' --no-headers )
}

print_context() {
  if [[ "$ALL_NAMESPACES" -eq 1 ]]; then
    echo "[pod-node-distribution] scope: all namespaces"
  else
    echo "[pod-node-distribution] namespace: $NAMESPACE"
  fi

  if [[ -n "$TARGET_NODE" ]]; then
    echo "[pod-node-distribution] node filter: $TARGET_NODE"
  fi
}

print_summary() {
  local input="$1"

  echo
  echo "Node Summary"
  printf '%-40s %5s\n' "NODE" "PODS"
  printf '%-40s %5s\n' "----" "----"

  awk '
    {
      node = $4
      if (node == "" || node == "<none>") {
        node = "UNSCHEDULED"
      }
      counts[node]++
    }
    END {
      for (node in counts) {
        printf "%-40s %5d\n", node, counts[node]
      }
    }
  ' <<< "$input" | sort
}

parse_args "$@"

echo "[pod-node-distribution] checking required tools"
require_command kubectl

declare -a kubectl_args
build_kubectl_args kubectl_args

print_context

pod_rows="$(kubectl "${kubectl_args[@]}")"

if [[ -z "$pod_rows" ]]; then
  echo "[pod-node-distribution] no pods found for the selected scope"
  exit 0
fi

sorted_rows="$(printf '%s\n' "$pod_rows" | sort -k4,4 -k1,1 -k2,2)"

echo
echo "Pod Placement"
printf '%-24s %-44s %-12s %-40s %-15s\n' "NAMESPACE" "POD" "STATUS" "NODE" "IP"
printf '%-24s %-44s %-12s %-40s %-15s\n' "---------" "---" "------" "----" "--"

awk '
  {
    node = $4
    if (node == "" || node == "<none>") {
      node = "UNSCHEDULED"
    }

    ip = $5
    if (ip == "") {
      ip = "-"
    }

    printf "%-24s %-44s %-12s %-40s %-15s\n", $1, $2, $3, node, ip
  }
' <<< "$sorted_rows"

print_summary "$sorted_rows"