#!/usr/bin/env bash
# Reconfigure Koofr top-level folders to LoveCloud six-digit PARA names.
# Uses rclone server-side DirMove (no copy, no --delete).
#
# Usage:
#   ./apply-para-layout.sh            # apply
#   ./apply-para-layout.sh --dry-run  # print actions only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${KOOFR_RCLONE_CONF:-${SCRIPT_DIR}/rclone.conf}"
REMOTE="${KOOFR_REMOTE:-koofr}"
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -f "${CONF}" ]]; then
  echo "Missing ${CONF}. Create rclone.conf (gitignored) first." >&2
  exit 1
fi

RC=(rclone --config "${CONF}")

log() { printf '%s\n' "$*"; }

list_dirs() {
  "${RC[@]}" lsf "${REMOTE}:${1}" --dirs-only 2>/dev/null | sed 's:/$::' || true
}

dir_exists() {
  local path="$1"
  local parent name
  parent="$(dirname "${path}")"
  name="$(basename "${path}")"
  if [[ "${parent}" == "." ]]; then
    list_dirs "" | grep -Fxq "${name}"
  else
    list_dirs "${parent}" | grep -Fxq "${name}"
  fi
}

ensure_dir() {
  local dest="$1"
  if dir_exists "${dest}"; then
    log "SKIP mkdir ${dest} (exists)"
    return 0
  fi
  log "MKDIR ${dest}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  "${RC[@]}" mkdir "${REMOTE}:${dest}"
}

rename_dir() {
  local src="$1" dest="$2"
  if dir_exists "${dest}"; then
    if dir_exists "${src}"; then
      log "WARN dest exists, leaving source: ${src} -> ${dest}"
    else
      log "SKIP ${src} -> ${dest} (already renamed)"
    fi
    return 0
  fi
  if ! dir_exists "${src}"; then
    log "SKIP missing source ${src}"
    return 0
  fi
  log "MOVE ${src} -> ${dest}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  "${RC[@]}" moveto "${REMOTE}:${src}" "${REMOTE}:${dest}"
}

# 01001-uploads -> 010001_uploads (insert 0 after the two-digit PARA root).
# Leaves 1xxxx / 2xxxx / 5xxxx historical aliases untouched.
upgrade_five_digit_children() {
  local parent="$1" line code rest six dest
  if ! dir_exists "${parent}"; then
    return 0
  fi
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    if [[ "${line}" =~ ^(0[1-9][0-9]{3})-(.+)$ ]]; then
      code="${BASH_REMATCH[1]}"
      rest="${BASH_REMATCH[2]}"
      six="${code:0:2}0${code:2}"
      dest="${six}_${rest}"
      rename_dir "${parent}/${line}" "${parent}/${dest}"
    fi
  done < <(list_dirs "${parent}")
}

seed() {
  local parent="$1"
  shift
  ensure_dir "${parent}"
  local child
  for child in "$@"; do
    ensure_dir "${parent}/${child}"
  done
}

log "=== LoveCloud six-digit PARA on ${REMOTE}: (dry_run=${DRY_RUN}) ==="

ensure_dir "060000_PRIVATE-MEDIA__koofr"
ensure_dir "080000_APPLICATION-DATA__koofr"
ensure_dir "090000_QUARANTINE__koofr"

rename_dir "@INBOX_koofr" "010000_INBOX__koofr"
rename_dir "@PROJECTS_koofr" "020000_PROJECTS__koofr"
rename_dir "@AREAS_koofr" "030000_AREAS__koofr"
rename_dir "@RESOURCES_koofr" "040000_RESOURCES__koofr"
rename_dir "@ARCHIVES_koofr" "050000_ARCHIVES__koofr"
rename_dir "_SYSTEM" "070000_SYSTEM-AUTOMATION__koofr"
rename_dir "Stash" "060000_PRIVATE-MEDIA__koofr/Stash"

rename_dir "inbox-idrive-e2" "010000_INBOX__idrive-e2"
rename_dir "projects-idrive-e2" "020000_PROJECTS__idrive-e2"
rename_dir "areas-idrive-e2" "030000_AREAS__idrive-e2"
rename_dir "resources-idrive-e2" "040000_RESOURCES__idrive-e2"
rename_dir "archives-idrive-e2" "050000_ARCHIVES__idrive-e2"
rename_dir "private-idrive-e2" "060000_PRIVATE-MEDIA__idrive-e2"
rename_dir "shannon-photos-e2" "060010_PHOTOS__idrive-e2"
rename_dir "video-media-e2" "060020_VIDEO-MEDIA__idrive-e2"
rename_dir "graphics-media-e2" "060030_GRAPHICS__idrive-e2"
rename_dir "agent-data-e2" "070010_AGENT-DATA__idrive-e2"
rename_dir "assets-e2" "070020_ASSETS__idrive-e2"
rename_dir "stacks-backups-e2" "070030_STACKS-BACKUPS__idrive-e2"
rename_dir "n8n-backups-e2" "080010_N8N-BACKUPS__idrive-e2"
rename_dir "bookstack-data-e2" "080020_BOOKSTACK__idrive-e2"
rename_dir "paperless-docs-e2" "080030_PAPERLESS__idrive-e2"
rename_dir "quarantine-e2" "090000_QUARANTINE__idrive-e2"

upgrade_five_digit_children "010000_INBOX__idrive-e2"
upgrade_five_digit_children "020000_PROJECTS__idrive-e2"
upgrade_five_digit_children "030000_AREAS__idrive-e2"
upgrade_five_digit_children "040000_RESOURCES__idrive-e2"
upgrade_five_digit_children "050000_ARCHIVES__idrive-e2"
upgrade_five_digit_children "060000_PRIVATE-MEDIA__idrive-e2"
upgrade_five_digit_children "060010_PHOTOS__idrive-e2"
upgrade_five_digit_children "060020_VIDEO-MEDIA__idrive-e2"
upgrade_five_digit_children "060030_GRAPHICS__idrive-e2"
upgrade_five_digit_children "070010_AGENT-DATA__idrive-e2"
upgrade_five_digit_children "070020_ASSETS__idrive-e2"
upgrade_five_digit_children "070030_STACKS-BACKUPS__idrive-e2"
upgrade_five_digit_children "080010_N8N-BACKUPS__idrive-e2"
upgrade_five_digit_children "080020_BOOKSTACK__idrive-e2"
upgrade_five_digit_children "080030_PAPERLESS__idrive-e2"
upgrade_five_digit_children "090000_QUARANTINE__idrive-e2"

seed "010000_INBOX__koofr" \
  010001_uploads 010002_processing 010003_stabilization 010004_review hazel-ready
seed "020000_PROJECTS__koofr" \
  020001_web-projects 020002_media-productions 020003_dev-projects 020004_content-projects
seed "030000_AREAS__koofr" \
  030001_infrastructure-and-ops 030002_content-and-media 030003_personal-development \
  030004_editing-and-graphics 030005_learning-and-tutorials
seed "040000_RESOURCES__koofr" \
  040001_reference-materials 040002_tools-and-software 040003_design-resources 040004_entertainment
seed "050000_ARCHIVES__koofr" \
  050001_video-project-archives 050002_project-archives 050003_document-archives
seed "060000_PRIVATE-MEDIA__koofr" \
  060001_credentials 060002_personal-docs 060003_server-configs 060004_legal \
  060010_photos 060020_video-media 060030_graphics
seed "070000_SYSTEM-AUTOMATION__koofr" \
  070010_agent-data 070020_assets 070030_stacks-backups
seed "080000_APPLICATION-DATA__koofr" \
  080010_n8n 080020_bookstack 080030_paperless
seed "090000_QUARANTINE__koofr" \
  090001_conflicts 090002_failures 090003_unsupported 090004_remediation

log "=== done ==="
