#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/kube-vip.yaml"
KVVERSION="v1.2.3"
VIP="192.168.0.200"
INTERFACE="eth0"
TEMP_FILE="$(mktemp)"
NORMALIZED_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE" "$NORMALIZED_FILE"' EXIT

podman pull "ghcr.io/kube-vip/kube-vip:$KVVERSION"
podman run --rm --network host \
    --entrypoint /kube-vip \
    "ghcr.io/kube-vip/kube-vip:$KVVERSION" \
    manifest pod \
    --interface "$INTERFACE" \
    --address "$VIP" \
    --controlplane \
    --services \
    --arp \
    --leaderElection > "$TEMP_FILE"

awk '
    function flush_blank_lines() {
        while (blank_lines > 0) {
            print ""
            blank_lines--
        }
    }

    /^    - name: svc_enable$/ {
        found = 1
        flush_blank_lines()
        print
        getline
        sub(/value: "true"/, "value: \"false\"")
        print
        next
    }
    /^[[:space:]]*$/ {
        blank_lines++
        next
    }
    {
        flush_blank_lines()
        print
    }
    END {
        if (!found) {
            exit 1
        }
    }
' "$TEMP_FILE" > "$NORMALIZED_FILE"

mv "$NORMALIZED_FILE" "$OUTPUT_FILE"
trap - EXIT
echo "generated $OUTPUT_FILE"
