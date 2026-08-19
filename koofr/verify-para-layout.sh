#!/usr/bin/env bash
# Fail if Koofr top-level PARA folders are missing or old unnumbered names remain.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${KOOFR_RCLONE_CONF:-${SCRIPT_DIR}/rclone.conf}"
REMOTE="${KOOFR_REMOTE:-koofr}"

if [[ ! -f "${CONF}" ]]; then
  echo "Missing ${CONF}" >&2
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

forbid() {
  local name="$1"
  if printf '%s\n' "${listing}" | grep -Fxq "${name}"; then
    echo "LEFT ${name}" >&2
    fail=1
  else
    echo "GONE ${name}"
  fi
}

expect "010000_INBOX__koofr"
expect "020000_PROJECTS__koofr"
expect "030000_AREAS__koofr"
expect "040000_RESOURCES__koofr"
expect "050000_ARCHIVES__koofr"
expect "060000_PRIVATE-MEDIA__koofr"
expect "070000_SYSTEM-AUTOMATION__koofr"
expect "080000_APPLICATION-DATA__koofr"
expect "090000_QUARANTINE__koofr"
expect "010000_INBOX__idrive-e2"
expect "020000_PROJECTS__idrive-e2"
expect "030000_AREAS__idrive-e2"
expect "040000_RESOURCES__idrive-e2"
expect "050000_ARCHIVES__idrive-e2"
expect "060000_PRIVATE-MEDIA__idrive-e2"
expect "060010_PHOTOS__idrive-e2"
expect "060020_VIDEO-MEDIA__idrive-e2"
expect "060030_GRAPHICS__idrive-e2"
expect "070010_AGENT-DATA__idrive-e2"
expect "070020_ASSETS__idrive-e2"
expect "070030_STACKS-BACKUPS__idrive-e2"
expect "080010_N8N-BACKUPS__idrive-e2"
expect "080020_BOOKSTACK__idrive-e2"
expect "080030_PAPERLESS__idrive-e2"
expect "090000_QUARANTINE__idrive-e2"

forbid "@INBOX_koofr"
forbid "@PROJECTS_koofr"
forbid "@AREAS_koofr"
forbid "@RESOURCES_koofr"
forbid "@ARCHIVES_koofr"
forbid "_SYSTEM"
forbid "Stash"
forbid "inbox-idrive-e2"
forbid "projects-idrive-e2"
forbid "areas-idrive-e2"
forbid "resources-idrive-e2"
forbid "archives-idrive-e2"
forbid "private-idrive-e2"
forbid "video-media-e2"
forbid "quarantine-e2"

if rclone --config "${CONF}" ls "${REMOTE}:060000_PRIVATE-MEDIA__koofr/Stash/media" | grep -q .; then
  echo "OK   Stash library at 060000_PRIVATE-MEDIA__koofr/Stash/media"
else
  echo "WARN Stash library path exists but is empty" >&2
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "PARA layout check failed" >&2
  exit 1
fi
echo "PARA layout check passed"
