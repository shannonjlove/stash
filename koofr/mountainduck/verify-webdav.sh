#!/usr/bin/env bash
# Confirm Koofr WebDAV (koofr2) sees the LoveCloud six-digit PARA roots.
# Does not require Mountain Duck. Uses rclone WebDAV.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOOFR_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${KOOFR_ENV:-${KOOFR_DIR}/.env}"
NATIVE_CONF="${KOOFR_RCLONE_CONF:-${KOOFR_DIR}/rclone.conf}"
GENERATED_CONF="${SCRIPT_DIR}/generated/rclone-koofr2.conf"
TMP_CONF=""
cleanup() {
  if [[ -n "${TMP_CONF}" && -f "${TMP_CONF}" ]]; then
    rm -f "${TMP_CONF}"
  fi
}
trap cleanup EXIT

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

CONF=""
REMOTE="koofr2"

if [[ -n "${KOOFR2_RCLONE_CONF:-}" && -f "${KOOFR2_RCLONE_CONF}" ]]; then
  CONF="${KOOFR2_RCLONE_CONF}"
elif [[ -f "${GENERATED_CONF}" ]]; then
  CONF="${GENERATED_CONF}"
elif [[ -n "${KOOFR2_APP_PASSWORD:-}" ]]; then
  TMP_CONF="$(mktemp)"
  chmod 600 "${TMP_CONF}"
  obscured="$(rclone obscure "${KOOFR2_APP_PASSWORD}")"
  cat > "${TMP_CONF}" <<EOF
[koofr2]
type = webdav
url = ${KOOFR2_WEBDAV_URL:-https://app.koofr.net/dav/Koofr}
vendor = other
user = ${KOOFR2_USER:-shannonjlove@mac.com}
pass = ${obscured}
EOF
  CONF="${TMP_CONF}"
elif [[ -f "${NATIVE_CONF}" ]] && grep -q '^\[koofr\]' "${NATIVE_CONF}"; then
  # Same account: reuse native rclone user/pass against WebDAV.
  TMP_CONF="$(mktemp)"
  chmod 600 "${TMP_CONF}"
  python3 - "${NATIVE_CONF}" "${TMP_CONF}" <<'PY'
import pathlib
import sys

src, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
user = passwd = None
in_koofr = False
for line in src.read_text(encoding="utf-8").splitlines():
    if line.startswith("[") and line.endswith("]"):
        in_koofr = line == "[koofr]"
        continue
    if not in_koofr or "=" not in line:
        continue
    key, value = line.split("=", 1)
    key, value = key.strip(), value.strip()
    if key == "user":
        user = value
    elif key in ("pass", "password"):
        passwd = value
if not user or not passwd:
    raise SystemExit(f"{src}: [koofr] missing user/password")
dest.write_text(
    "[koofr2]\n"
    "type = webdav\n"
    "url = https://app.koofr.net/dav/Koofr\n"
    "vendor = other\n"
    f"user = {user}\n"
    f"pass = {passwd}\n",
    encoding="utf-8",
)
PY
  CONF="${TMP_CONF}"
  echo "Using WebDAV credentials derived from native ${NATIVE_CONF}"
else
  echo "Need KOOFR2_APP_PASSWORD, ${GENERATED_CONF}, or ${NATIVE_CONF}" >&2
  exit 1
fi

listing="$(rclone --config "${CONF}" lsf "${REMOTE}:" --dirs-only | sed 's:/$::')"
fail=0

expect() {
  local name="$1"
  if printf '%s\n' "${listing}" | grep -Fxq "${name}"; then
    echo "OK   ${name}"
  else
    echo "MISS ${name}" >&2
    fail=1
  fi
}

echo "=== koofr2 WebDAV PARA roots ==="
expect "010000_INBOX__koofr"
expect "020000_PROJECTS__koofr"
expect "030000_AREAS__koofr"
expect "040000_RESOURCES__koofr"
expect "050000_ARCHIVES__koofr"
expect "060000_PRIVATE-MEDIA__koofr"
expect "070000_SYSTEM-AUTOMATION__koofr"
expect "080000_APPLICATION-DATA__koofr"
expect "090000_QUARANTINE__koofr"

SMOKE="060000_PRIVATE-MEDIA__koofr/Stash/media/stash-koofr-smoketest.mp4"
if rclone --config "${CONF}" lsf "${REMOTE}:${SMOKE}" >/dev/null 2>&1; then
  echo "OK   ${SMOKE}"
else
  echo "MISS ${SMOKE}" >&2
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "WebDAV PARA check failed" >&2
  exit 1
fi
echo "WebDAV PARA check passed"
