#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

tmp=""
trap '[[ -n "$tmp" ]] && rm -f "$tmp"' EXIT

case "${1:-}" in
  lab) dir=coreos-lab ;;
  pis) dir=coreos-pis ;;
  "")
    echo "usage: $0 {lab|pis}" >&2
    exit 1
    ;;
  *)
    echo "error: unknown target '$1' (expected lab or pis)" >&2
    exit 1
    ;;
esac

SECRETS_FILE="${SECRETS_FILE:-$SCRIPT_DIR/$dir/.secrets.env}"
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "error: missing $SECRETS_FILE (copy $dir/.secrets.env.template and fill in values)" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$SECRETS_FILE"

if [[ -z "${SSH_PUBLIC_KEY:-}" || -z "${PASSWORD_HASH:-}" ]]; then
  echo "error: SSH_PUBLIC_KEY and PASSWORD_HASH must be set in $SECRETS_FILE" >&2
  exit 1
fi

if ! command -v butane >/dev/null 2>&1; then
  echo "error: butane not found in PATH" >&2
  exit 1
fi

for bu in "$dir"/*.bu; do
  [[ -f "$bu" ]] || continue
  out="${bu%.bu}.ign"
  tmp="$(mktemp)"
  sed "s|{{ SSH_PUBLIC_KEY }}|$SSH_PUBLIC_KEY|g; s|{{ PASSWORD_HASH }}|$PASSWORD_HASH|g" "$bu" \
    | butane --pretty --strict > "$tmp"
  mv "$tmp" "$out"
  echo "rendered $out"
done
