#!/usr/bin/env bash
# Deploy Stash with the media library on Koofr cloud storage.
#
# Usage:
#   cp .env.example .env   # then edit credentials
#   ./deploy-koofr.sh
#
# The script prefers the rclone Docker volume plugin. If plugin install fails,
# it falls back to docker-compose.sidecar.yml (FUSE mount sidecar).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
CONF_FILE="${SCRIPT_DIR}/rclone.conf"
COMPOSE_PLUGIN="${SCRIPT_DIR}/docker-compose.yml"
COMPOSE_SIDECAR="${SCRIPT_DIR}/docker-compose.sidecar.yml"
PLUGIN_CONFIG_DIR="/var/lib/docker-plugins/rclone/config"
PLUGIN_CACHE_DIR="/var/lib/docker-plugins/rclone/cache"
SYSTEMD_UNIT="/etc/systemd/system/stash-koofr.service"
COMPOSE_MODE="plugin"

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

detect_plugin_image() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "rclone/docker-volume-rclone:amd64" ;;
    aarch64|arm64) echo "rclone/docker-volume-rclone:arm64" ;;
    armv7l) echo "rclone/docker-volume-rclone:arm-v7" ;;
    *)
      print_error "Unsupported architecture: ${arch}"
      return 1
      ;;
  esac
}

ensure_env() {
  print_section "Checking environment file"
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

ensure_docker() {
  print_section "Checking Docker"
  if ! command -v docker >/dev/null 2>&1; then
    print_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    need_root_for sh /tmp/get-docker.sh
    if [[ "${EUID}" -ne 0 ]]; then
      need_root_for usermod -aG docker "${USER}"
      print_info "Added ${USER} to the docker group. If docker commands fail, log out and back in."
    fi
  fi
  if ! docker info >/dev/null 2>&1; then
    print_error "Docker is installed but not usable. Start the daemon or re-login after joining the docker group."
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    print_error "docker compose is required."
    exit 1
  fi
  print_success "Docker is ready"
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

ensure_rclone_conf() {
  print_section "Checking rclone.conf"
  if [[ ! -f "${CONF_FILE}" ]]; then
    "${SCRIPT_DIR}/setup-rclone.sh"
  else
    print_success "Using existing ${CONF_FILE}"
  fi
}

rclone_koofr() {
  docker run --rm \
    -v "${CONF_FILE}:/config/rclone/rclone.conf:ro" \
    rclone/rclone:latest \
    "$@"
}

verify_koofr() {
  print_section "Verifying Koofr credentials"
  local remote="${KOOFR_REMOTE:-koofr}"
  local path="${KOOFR_PATH:-Stash/media}"
  local parent
  rclone_koofr lsd "${remote}:" >/dev/null
  print_success "Authenticated to Koofr"

  print_info "Ensuring remote folder ${remote}:${path} exists"
  parent="$(dirname "${path}")"
  if [[ "${parent}" != "." ]]; then
    rclone_koofr mkdir "${remote}:${parent}" || true
  fi
  rclone_koofr mkdir "${remote}:${path}" || true
  rclone_koofr lsd "${remote}:${path}" >/dev/null
  print_success "Remote folder is reachable"
}

install_rclone_plugin() {
  print_section "Installing rclone Docker volume plugin"
  need_root_for mkdir -p "${PLUGIN_CONFIG_DIR}" "${PLUGIN_CACHE_DIR}"
  need_root_for cp "${CONF_FILE}" "${PLUGIN_CONFIG_DIR}/rclone.conf"
  need_root_for chmod 600 "${PLUGIN_CONFIG_DIR}/rclone.conf"

  if docker plugin inspect rclone >/dev/null 2>&1; then
    print_success "rclone plugin already installed"
    return 0
  fi

  local image
  image="$(detect_plugin_image)"
  docker plugin install "${image}" args="-v" --alias rclone --grant-all-permissions
  print_success "Installed ${image} as rclone"
}

seed_stash_config() {
  print_section "Seeding local Stash directories"
  mkdir -p \
    "${SCRIPT_DIR}/data/config" \
    "${SCRIPT_DIR}/data/metadata" \
    "${SCRIPT_DIR}/data/cache" \
    "${SCRIPT_DIR}/data/blobs" \
    "${SCRIPT_DIR}/data/generated" \
    "${SCRIPT_DIR}/data/rclone-vfs"
  if [[ ! -f "${SCRIPT_DIR}/data/config/config.yml" ]]; then
    cp "${SCRIPT_DIR}/config.yml.example" "${SCRIPT_DIR}/data/config/config.yml"
    print_success "Installed cloud-friendly config.yml"
  else
    print_success "Existing config.yml left in place"
  fi
}

start_plugin_stack() {
  print_section "Starting Stash (rclone volume plugin)"
  (cd "${SCRIPT_DIR}" && docker compose -f "${COMPOSE_PLUGIN}" up -d)
  COMPOSE_MODE="plugin"
  print_success "Stack started with docker-compose.yml"
}

start_sidecar_stack() {
  print_section "Starting Stash (rclone sidecar mount)"
  local mount_point="${KOOFR_MOUNT_POINT:-/mnt/koofr}"
  need_root_for mkdir -p "${mount_point}"
  (cd "${SCRIPT_DIR}" && docker compose -f "${COMPOSE_SIDECAR}" up -d)
  COMPOSE_MODE="sidecar"
  print_success "Stack started with docker-compose.sidecar.yml"
}

install_systemd_unit() {
  print_section "Installing systemd unit"
  local compose_file="${COMPOSE_PLUGIN}"
  if [[ "${COMPOSE_MODE}" == "sidecar" ]]; then
    compose_file="${COMPOSE_SIDECAR}"
  fi
  need_root_for tee "${SYSTEMD_UNIT}" >/dev/null <<EOF
[Unit]
Description=Stash with Koofr media library
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/usr/bin/docker compose -f ${compose_file} up -d
ExecStop=/usr/bin/docker compose -f ${compose_file} down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
  need_root_for systemctl daemon-reload
  need_root_for systemctl enable --now stash-koofr.service
  print_success "Enabled stash-koofr.service"
}

print_next_steps() {
  local port="${STASH_PORT:-9999}"
  echo
  print_success "Stash is running with the Koofr library at /data"
  echo "  UI:            http://localhost:${port}"
  echo "  Media remote:  ${KOOFR_REMOTE:-koofr}:${KOOFR_PATH:-Stash/media}"
  echo "  Compose mode:  ${COMPOSE_MODE}"
  echo
  echo "Upload videos/images into that Koofr folder, then run a Scan in Stash."
  echo "Keep generated files, cache, blobs, and the SQLite database on local volumes."
}

main() {
  echo
  echo "Stash + Koofr deploy"
  echo

  if [[ "$(uname -s)" != "Linux" ]]; then
    print_error "This deploy script targets Linux hosts with Docker and FUSE."
    exit 1
  fi

  ensure_env
  ensure_docker
  ensure_fuse
  ensure_rclone_conf
  verify_koofr

  seed_stash_config

  if install_rclone_plugin && start_plugin_stack; then
    :
  else
    print_info "Volume plugin path failed; using sidecar mount instead."
    (cd "${SCRIPT_DIR}" && docker compose -f "${COMPOSE_PLUGIN}" down --remove-orphans) || true
    start_sidecar_stack
  fi

  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    install_systemd_unit || print_info "Could not install systemd unit; stack is still running under Docker."
  fi

  print_next_steps
}

main "$@"
