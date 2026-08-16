#!/usr/bin/env bash
# Restart stash if the container exits. For hosts without systemd.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while true; do
  if ! podman inspect stash --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
    echo "$(date -u +%FT%TZ) stash not running; restarting"
    "${SCRIPT_DIR}/run-stack.sh" || true
  fi
  sleep 15
done
