#!/usr/bin/env bash
# Run Stash + Koofr on a host without systemd (Podman). Mounts Koofr inside
# the Stash container so FUSE is visible (rootless bind-mounts hide host FUSE).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SCRIPT_DIR}/rclone.conf"
DATA="${SCRIPT_DIR}/data"
IMAGE="${STASH_IMAGE:-docker.io/stashapp/stash:latest}"

if [[ ! -f "${CONF}" ]]; then
  echo "Missing ${CONF}. Copy .env.example to .env and run ./setup-rclone.sh" >&2
  exit 1
fi

mkdir -p "${DATA}"/{config,metadata,cache,blobs,generated,rclone-vfs}
if [[ ! -f "${DATA}/config/config.yml" ]]; then
  cp "${SCRIPT_DIR}/config.yml.example" "${DATA}/config/config.yml"
fi

command -v podman >/dev/null 2>&1 || { echo "podman is required" >&2; exit 1; }
command -v rclone >/dev/null 2>&1 || { echo "rclone is required on the host (bind-mounted into the container)" >&2; exit 1; }

podman pull "${IMAGE}" >/dev/null
podman rm -f stash >/dev/null 2>&1 || true

podman run -d --name stash --privileged --device /dev/fuse \
  --hostname stash \
  -p "${STASH_PORT:-9999}:9999" \
  -e STASH_STASH=/data/ \
  -e STASH_GENERATED=/generated/ \
  -e STASH_METADATA=/metadata/ \
  -e STASH_CACHE=/cache/ \
  -e STASH_PORT=9999 \
  -e TZ="${TZ:-Etc/UTC}" \
  -v /usr/bin/rclone:/usr/local/bin/rclone:ro \
  -v "${CONF}:/config/rclone/rclone.conf:ro" \
  -v "${DATA}/config:/root/.stash" \
  -v "${DATA}/metadata:/metadata" \
  -v "${DATA}/cache:/cache" \
  -v "${DATA}/blobs:/blobs" \
  -v "${DATA}/generated:/generated" \
  -v "${DATA}/rclone-vfs:/vfs" \
  --entrypoint /bin/sh \
  "${IMAGE}" \
  -c 'apk add --no-cache fuse3 >/dev/null && mkdir -p /data && /usr/local/bin/rclone mount koofr:Stash/media /data --config /config/rclone/rclone.conf --vfs-cache-mode full --cache-dir /vfs --allow-other --dir-cache-time 30s --log-file /tmp/rclone-mount.log &
sleep 3
exec stash'

echo "Stash is starting at http://127.0.0.1:${STASH_PORT:-9999}"
echo "Library: Koofr:Stash/media -> /data"
