#!/usr/bin/env bash
# Install Stash + Koofr as always-on Podman quadlets.
#
# Usage:
#   ./setup-quadlet.sh          # user service + linger (survives logout)
#   sudo ./setup-quadlet.sh system
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-user}"
ENV_FILE="${SCRIPT_DIR}/.env"
CONF_FILE="${SCRIPT_DIR}/rclone.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_section() { echo -e "\n${BLUE}→ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}" >&2; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

need_root_for() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

systemctl_cmd() {
  if [[ "${MODE}" == "system" ]]; then
    need_root_for systemctl "$@"
  else
    systemctl --user "$@"
  fi
}

check_mode() {
  case "${MODE}" in
    user|system) ;;
    *)
      print_error "Usage: $0 [user|system]"
      exit 1
      ;;
  esac
  if [[ "${MODE}" == "system" && "${EUID}" -ne 0 ]]; then
    print_error "System-wide install requires root. Run: sudo $0 system"
    exit 1
  fi
}

check_podman() {
  print_section "Checking Podman"
  if ! command -v podman >/dev/null 2>&1; then
    print_error "Podman is not installed. Install Podman 4.4+ first."
    exit 1
  fi
  local version major minor
  version="$(podman --version | awk '{print $3}')"
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"
  if [[ "${major}" -lt 4 ]] || { [[ "${major}" -eq 4 ]] && [[ "${minor}" -lt 4 ]]; }; then
    print_error "Podman 4.4+ is required for quadlets (found ${version})"
    exit 1
  fi
  print_success "Podman ${version}"
}

check_systemd() {
  print_section "Checking systemd"
  if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
    print_error "systemd is required for quadlets."
    exit 1
  fi
  print_success "systemd is available"
}

ensure_fuse() {
  print_section "Checking FUSE"
  if [[ ! -e /dev/fuse ]]; then
    print_error "/dev/fuse is missing. Install fuse3 and reboot if needed."
    exit 1
  fi
  if ! command -v fusermount3 >/dev/null 2>&1 && ! command -v fusermount >/dev/null 2>&1; then
    print_info "Installing fuse3..."
    if command -v apt-get >/dev/null 2>&1; then
      need_root_for apt-get update -qq
      need_root_for apt-get install -y fuse3
    elif command -v dnf >/dev/null 2>&1; then
      need_root_for dnf install -y fuse3
    else
      print_error "Install fuse3 with your package manager, then re-run."
      exit 1
    fi
  fi
  if [[ -f /etc/fuse.conf ]] && ! grep -qE '^user_allow_other' /etc/fuse.conf; then
    print_info "Enabling user_allow_other in /etc/fuse.conf"
    need_root_for sh -c "echo 'user_allow_other' >> /etc/fuse.conf"
  fi
  print_success "FUSE is ready"
}

ensure_env() {
  print_section "Loading .env"
  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${SCRIPT_DIR}/.env.example" "${ENV_FILE}"
    print_error "Created ${ENV_FILE}. Fill in KOOFR_USER and KOOFR_APP_PASSWORD, then re-run."
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
  print_success "Loaded ${ENV_FILE}"
}

ensure_rclone_conf() {
  print_section "Checking rclone.conf"
  if [[ ! -f "${CONF_FILE}" ]]; then
    "${SCRIPT_DIR}/setup-rclone.sh"
  else
    print_success "Using existing ${CONF_FILE}"
  fi
}

ensure_rc_env() {
  print_section "Checking rclone RC API token"
  local rc_env="${SCRIPT_DIR}/koofr-rc.env"
  if [[ ! -f "${rc_env}" ]]; then
    local token
    token="$(openssl rand -base64 36 | tr -d '/+=' | head -c 40)"
    umask 077
    cat > "${rc_env}" <<EOF
RCLONE_RC_USER=cursor-agent
RCLONE_RC_PASS=${token}
RCLONE_RC_ADDR=127.0.0.1:5572
EOF
    chmod 600 "${rc_env}"
    print_success "Generated ${rc_env}"
  else
    print_success "Using existing ${rc_env}"
  fi
}

rclone_koofr() {
  if command -v rclone >/dev/null 2>&1; then
    rclone --config "${CONF_FILE}" "$@"
  else
    local runtime=podman
    command -v podman >/dev/null 2>&1 || runtime=docker
    "${runtime}" run --rm \
      -v "${CONF_FILE}:/config/rclone/rclone.conf:ro" \
      docker.io/rclone/rclone:latest \
      "$@"
  fi
}

verify_koofr() {
  print_section "Verifying Koofr"
  local remote="${KOOFR_REMOTE:-koofr}"
  local path="${KOOFR_PATH:-Stash/media}"
  local parent
  rclone_koofr lsd "${remote}:" >/dev/null
  print_success "Authenticated to Koofr"
  parent="$(dirname "${path}")"
  if [[ "${parent}" != "." ]]; then
    rclone_koofr mkdir "${remote}:${parent}" || true
  fi
  rclone_koofr mkdir "${remote}:${path}" || true
  print_success "Remote folder ${remote}:${path} is ready"
}

apply_unit_substitutions() {
  local file="$1"
  local remote="${KOOFR_REMOTE:-koofr}"
  local path="${KOOFR_PATH:-Stash/media}"
  local vfs="${RCLONE_VFS_CACHE_MAX_SIZE:-10G}"
  local port="${STASH_PORT:-9999}"
  local tz="${TZ:-Etc/UTC}"
  sed -i \
    -e "s|mount koofr:Stash/media |mount ${remote}:${path} |" \
    -e "s|--vfs-cache-max-size 10G|--vfs-cache-max-size ${vfs}|" \
    -e "s|PublishPort=9999:9999|PublishPort=${port}:9999|" \
    -e "s|Environment=TZ=Etc/UTC|Environment=TZ=${tz}|" \
    "${file}"
}

install_user() {
  local dest="${HOME}/.config/containers/systemd"
  local state="${HOME}/.stash"

  print_section "Installing user quadlets (linger)"
  mkdir -p \
    "${dest}" \
    "${state}/config" \
    "${state}/koofr" \
    "${state}/metadata" \
    "${state}/cache" \
    "${state}/blobs" \
    "${state}/generated" \
    "${state}/rclone-vfs"

  install -m 600 "${CONF_FILE}" "${state}/rclone.conf"
  install -m 600 "${ENV_FILE}" "${state}/koofr.env"
  install -m 600 "${SCRIPT_DIR}/koofr-rc.env" "${state}/koofr-rc.env"
  if [[ ! -f "${state}/config/config.yml" ]]; then
    cp "${SCRIPT_DIR}/config.yml.example" "${state}/config/config.yml"
  fi

  install -m 644 "${SCRIPT_DIR}/quadlet/koofr-rclone.container" "${dest}/koofr-rclone.container"
  install -m 644 "${SCRIPT_DIR}/quadlet/koofr-rc.container" "${dest}/koofr-rc.container"
  install -m 644 "${SCRIPT_DIR}/quadlet/stash.container" "${dest}/stash.container"
  apply_unit_substitutions "${dest}/koofr-rclone.container"
  apply_unit_substitutions "${dest}/koofr-rc.container"
  apply_unit_substitutions "${dest}/stash.container"

  if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "${USER}"
    print_success "Linger enabled for ${USER} (survives logout)"
  else
    print_info "loginctl not found; enable linger so Stash stays up after logout"
  fi

  systemctl --user daemon-reload
  systemctl --user enable --now podman-auto-update.timer 2>/dev/null || true
  systemctl --user enable --now koofr-rclone.service
  systemctl --user enable --now stash.service
  print_success "User units enabled: koofr-rclone.service stash.service (RC API on 127.0.0.1:5572)"
}

install_system() {
  local dest="/etc/containers/systemd"

  print_section "Installing system quadlets (boot)"
  mkdir -p \
    "${dest}" \
    /etc/stash \
    /var/lib/stash/config \
    /var/lib/stash/metadata \
    /var/lib/stash/cache \
    /var/lib/stash/blobs \
    /var/lib/stash/generated \
    /var/lib/stash/rclone-vfs \
    /mnt/koofr

  install -m 600 "${CONF_FILE}" /etc/stash/rclone.conf
  install -m 600 "${ENV_FILE}" /etc/stash/koofr.env
  install -m 600 "${SCRIPT_DIR}/koofr-rc.env" /etc/stash/koofr-rc.env
  if [[ ! -f /var/lib/stash/config/config.yml ]]; then
    cp "${SCRIPT_DIR}/config.yml.example" /var/lib/stash/config/config.yml
  fi

  install -m 644 "${SCRIPT_DIR}/quadlet/koofr-rclone-system.container" "${dest}/koofr-rclone.container"
  install -m 644 "${SCRIPT_DIR}/quadlet/koofr-rc-system.container" "${dest}/koofr-rc.container"
  install -m 644 "${SCRIPT_DIR}/quadlet/stash-system.container" "${dest}/stash.container"
  apply_unit_substitutions "${dest}/koofr-rclone.container"
  apply_unit_substitutions "${dest}/koofr-rc.container"
  apply_unit_substitutions "${dest}/stash.container"

  systemctl daemon-reload
  systemctl enable --now podman-auto-update.timer 2>/dev/null || true
  systemctl enable --now koofr-rclone.service
  systemctl enable --now stash.service
  print_success "System units enabled: koofr-rclone.service stash.service (RC API on 127.0.0.1:5572)"
}

print_next_steps() {
  local port="${STASH_PORT:-9999}"
  echo
  print_success "Stash is installed as a living Podman quadlet"
  echo "  UI:           http://localhost:${port}"
  echo "  Media remote: ${KOOFR_REMOTE:-koofr}:${KOOFR_PATH:-Stash/media}"
  if [[ "${MODE}" == "system" ]]; then
    echo "  Status:       systemctl status stash.service koofr-rclone.service koofr-rc.service"
    echo "  Koofr API:    http://127.0.0.1:5572  (cursor-agent token in /etc/stash/koofr-rc.env)"
    echo "  Logs:         journalctl -u koofr-rclone.service -f"
  else
    echo "  Status:       systemctl --user status stash.service koofr-rclone.service koofr-rc.service"
    echo "  Koofr API:    http://127.0.0.1:5572  (cursor-agent token in ~/.stash/koofr-rc.env)"
    echo "  Logs:         journalctl --user -u koofr-rclone.service -f"
  fi
}

main() {
  echo
  echo "Stash + Koofr Podman quadlet"
  echo

  if [[ "$(uname -s)" != "Linux" ]]; then
    print_error "Quadlets target Linux with systemd and Podman."
    exit 1
  fi

  check_mode
  check_podman
  check_systemd
  ensure_fuse
  ensure_env
  ensure_rclone_conf
  ensure_rc_env
  verify_koofr

  if [[ "${MODE}" == "system" ]]; then
    install_system
  else
    install_user
  fi

  print_next_steps
}

main "$@"
