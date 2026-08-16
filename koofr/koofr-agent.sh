#!/usr/bin/env bash
# Read/write Koofr as the Cursor agent using gitignored rclone.conf,
# or the loopback rclone RC API when koofr-rc.service is running.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${KOOFR_RCLONE_CONF:-${SCRIPT_DIR}/rclone.conf}"
RC_ENV="${SCRIPT_DIR}/koofr-rc.env"

usage() {
  cat <<'EOF'
Usage:
  ./koofr-agent.sh lsd [path]
  ./koofr-agent.sh ls [path]
  ./koofr-agent.sh cat <remote-path>
  ./koofr-agent.sh copy <local> <koofr:path>
  ./koofr-agent.sh rc <rclone-rc-method> [args...]
  ./koofr-agent.sh -- <rclone args>

Examples:
  ./koofr-agent.sh lsd
  ./koofr-agent.sh lsd Stash/media
  ./koofr-agent.sh rc operations/about fs=koofr:
EOF
}

load_rc_env() {
  if [[ -f "${RC_ENV}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${RC_ENV}"
    set +a
  fi
}

rclone_direct() {
  if [[ ! -f "${CONF}" ]]; then
    echo "Missing ${CONF}. Run ./setup-rclone.sh first." >&2
    exit 1
  fi
  rclone --config "${CONF}" "$@"
}

rclone_rc_call() {
  load_rc_env
  if [[ -z "${RCLONE_RC_USER:-}" || -z "${RCLONE_RC_PASS:-}" ]]; then
    echo "Missing ${RC_ENV} with RCLONE_RC_USER and RCLONE_RC_PASS." >&2
    exit 1
  fi
  rclone rc \
    --url "http://${RCLONE_RC_ADDR:-127.0.0.1:5572}/" \
    --user "${RCLONE_RC_USER}" \
    --pass "${RCLONE_RC_PASS}" \
    "$@"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

cmd="$1"
shift
case "${cmd}" in
  -h|--help) usage ;;
  lsd)
    rclone_direct lsd "koofr:${1:-}"
    ;;
  ls)
    rclone_direct ls "koofr:${1:-}"
    ;;
  cat)
    rclone_direct cat "koofr:${1:?path required}"
    ;;
  copy)
    rclone_direct copy "${1:?local path}" "${2:?koofr:path}"
    ;;
  rc)
    rclone_rc_call "$@"
    ;;
  --)
    rclone_direct "$@"
    ;;
  *)
    rclone_direct "${cmd}" "$@"
    ;;
esac
