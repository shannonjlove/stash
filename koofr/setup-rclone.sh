#!/usr/bin/env bash
# Generate koofr/rclone.conf from KOOFR_USER and KOOFR_APP_PASSWORD in .env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
CONF_FILE="${SCRIPT_DIR}/rclone.conf"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env and fill in Koofr credentials." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "${ENV_FILE}"
set +a

if [[ -z "${KOOFR_USER:-}" || "${KOOFR_USER}" == "you@example.com" ]]; then
  echo "Set KOOFR_USER in ${ENV_FILE} to your Koofr account email." >&2
  exit 1
fi

if [[ -z "${KOOFR_APP_PASSWORD:-}" || "${KOOFR_APP_PASSWORD}" == "replace-with-koofr-app-password" ]]; then
  echo "Set KOOFR_APP_PASSWORD in ${ENV_FILE}." >&2
  echo "Create one at https://app.koofr.net/app/admin/preferences/password" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to obscure the Koofr app password." >&2
  exit 1
fi

echo "Obscuring Koofr app password with rclone..."
OBSCURED="$(docker run --rm rclone/rclone:latest obscure "${KOOFR_APP_PASSWORD}")"

REMOTE_NAME="${KOOFR_REMOTE:-koofr}"

umask 077
cat > "${CONF_FILE}" <<EOF
[${REMOTE_NAME}]
type = koofr
provider = koofr
user = ${KOOFR_USER}
password = ${OBSCURED}
EOF

chmod 600 "${CONF_FILE}"
echo "Wrote ${CONF_FILE}"
