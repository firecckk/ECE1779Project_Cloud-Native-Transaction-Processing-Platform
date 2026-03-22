#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SCHEMA="$REPO_ROOT/database/schema.sql"
TARGET_SCHEMA="$REPO_ROOT/k8s/base/schema.sql"

if [[ ! -f "$SOURCE_SCHEMA" ]]; then
  echo "[sync-schema] source schema not found: $SOURCE_SCHEMA" >&2
  exit 1
fi

cp "$SOURCE_SCHEMA" "$TARGET_SCHEMA"
echo "[sync-schema] synced $SOURCE_SCHEMA -> $TARGET_SCHEMA"
