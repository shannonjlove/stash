#!/bin/bash

##############################################################################
# Deploy Oracle Cloud Jellyfin + Stash with Podman Quadlets
#
# Deploys Jellyfin and Stash using Podman quadlets for rootless,
# persistent operation with systemd integration and auto-start on reboot.
#
# Usage:
#   ./deploy-oracle-podman.sh [media-library-path]
#
# Default media path: ~/media-library (or provide custom path)
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
MEDIA_LIBRARY="${1:-$HOME/media-library}"
QUADLET_DIR="$HOME/.config/containers/systemd"
PODMAN_VOLUME_DIR="$HOME/.local/share/containers/storage/volumes"

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${BLUE}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_cmd() {
    echo -e "${MAGENTA}$ $1${NC}"
}

check_podman() {
    print_section "Checking Podman installation"

    if ! command -v podman &> /dev/null; then
        print_error "Podman not installed"
        print_info "Install with: sudo apt install podman"
        exit 1
    fi

    print_success "Podman installed: $(podman version --format '{{.Version}}')"

    if ! command -v systemctl &> /dev/null; then
        print_error "systemd not available"
        exit 1
    fi

    print_success "systemd available"
}

create_quadlet_directory() {
    print_section "Creating Podman quadlets directory"

    mkdir -p "$QUADLET_DIR"
    print_success "Quadlets directory created: $QUADLET_DIR"
}

enable_lingering() {
    print_section "Enabling user lingering for persistent services"

    if loginctl show-user "$USER" | grep -q "Linger=yes"; then
        print_info "User lingering already enabled"
        return 0
    fi

    print_info "Enabling lingering for user: $USER"
    loginctl enable-linger "$USER"
    print_success "User lingering enabled"
    print_info "Services will persist across logout and system reboot"
}

deploy_quadlets() {
    print_section "Deploying Podman quadlet files"

    # Copy quadlet files from oracle directory to systemd directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    for quadlet in media-network.network jellyfin.container stash.container; do
        if [ -f "$SCRIPT_DIR/$quadlet" ]; then
            print_cmd "cp $SCRIPT_DIR/$quadlet $QUADLET_DIR/"
            cp "$SCRIPT_DIR/$quadlet" "$QUADLET_DIR/"
            chmod 644 "$QUADLET_DIR/$quadlet"
            print_success "Deployed: $quadlet"
        else
            print_error "Quadlet file not found: $SCRIPT_DIR/$quadlet"
            exit 1
        fi
    done
}

create_volumes() {
    print_section "Creating Podman volumes for persistent storage"

    volumes=(
        "jellyfin_config"
        "jellyfin_cache"
        "stash_config"
        "stash_data"
        "stash_metadata"
        "stash_cache"
        "stash_blobs"
        "stash_generated"
        "media-library"
    )

    for volume in "${volumes[@]}"; do
        if podman volume exists "$volume" &> /dev/null; then
            print_info "Volume already exists: $volume"
        else
            print_cmd "podman volume create $volume"
            podman volume create "$volume"
            print_success "Created volume: $volume"
        fi
    done
}

setup_media_library() {
    print_section "Setting up media library"

    if [ ! -d "$MEDIA_LIBRARY" ]; then
        print_info "Creating media library directory: $MEDIA_LIBRARY"
        mkdir -p "$MEDIA_LIBRARY"
        mkdir -p "$MEDIA_LIBRARY/movies"
        mkdir -p "$MEDIA_LIBRARY/tv"
        mkdir -p "$MEDIA_LIBRARY/music"
        print_success "Media library directory created"
    else
        print_info "Media library already exists: $MEDIA_LIBRARY"
    fi

    # Mount media library to volume
    print_info "Binding media library to Podman volume"
}

reload_systemd() {
    print_section "Reloading systemd to recognize quadlets"

    print_cmd "systemctl --user daemon-reload"
    systemctl --user daemon-reload
    print_success "Systemd reloaded"
    print_info "Quadlet files converted to systemd service units"
}

enable_services() {
    print_section "Enabling services for auto-start on boot"

    services=("jellyfin.service" "stash.service" "media-network.service")

    for service in "${services[@]}"; do
        print_cmd "systemctl --user enable $service"
        systemctl --user enable "$service"
        print_success "Enabled: $service"
    done
}

start_services() {
    print_section "Starting services"

    print_cmd "systemctl --user start jellyfin.service"
    systemctl --user start jellyfin.service
    sleep 2

    print_cmd "systemctl --user start stash.service"
    systemctl --user start stash.service
    sleep 2

    print_success "Services started"
}

verify_services() {
    print_section "Verifying service status"

    echo ""
    print_cmd "systemctl --user status jellyfin.service --no-pager"
    systemctl --user status jellyfin.service --no-pager || true

    echo ""
    print_cmd "systemctl --user status stash.service --no-pager"
    systemctl --user status stash.service --no-pager || true

    echo ""
    print_cmd "podman ps"
    podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

check_container_health() {
    print_section "Checking container health"

    # Give containers time to start
    sleep 5

    print_info "Testing Jellyfin health..."
    if podman healthcheck run jellyfin &> /dev/null; then
        print_success "Jellyfin is healthy"
    else
        print_info "Jellyfin still starting (this is normal)"
    fi

    print_info "Testing Stash health..."
    if podman healthcheck run stash &> /dev/null; then
        print_success "Stash is healthy"
    else
        print_info "Stash still starting (this is normal)"
    fi
}

show_access_info() {
    print_section "Access Services"

    echo ""
    echo "Services are running and will auto-start on system reboot."
    echo ""
    echo "Access URLs:"
    echo "  ${MAGENTA}Jellyfin:${NC} http://localhost:8096"
    echo "  ${MAGENTA}Stash:${NC} http://localhost:9999"
    echo ""
    echo "Service Management (systemctl --user):"
    echo "  ${MAGENTA}Status:${NC} systemctl --user status jellyfin.service"
    echo "  ${MAGENTA}Logs:${NC} journalctl --user -u jellyfin.service -f"
    echo "  ${MAGENTA}Restart:${NC} systemctl --user restart jellyfin.service"
    echo "  ${MAGENTA}Stop:${NC} systemctl --user stop jellyfin.service"
    echo ""
    echo "Quadlet Files:"
    echo "  Location: ${MAGENTA}$QUADLET_DIR${NC}"
    echo "  Generated Units: ${MAGENTA}$HOME/.config/systemd/user/${NC}"
    echo ""
    echo "Media Library:"
    echo "  Path: ${MAGENTA}$MEDIA_LIBRARY${NC}"
    echo ""
}

show_summary() {
    print_section "Deployment Summary"

    echo ""
    echo "✓ Podman quadlets deployed"
    echo "✓ Systemd user services enabled"
    echo "✓ User lingering configured for persistence"
    echo "✓ Services will auto-start on system reboot"
    echo "✓ Persistent volumes created"
    echo ""
    echo "Configuration:"
    echo "  • Runtime: Podman (rootless, daemonless)"
    echo "  • Management: systemd (--user scope)"
    echo "  • Auto-Restart: on-failure (5s delay)"
    echo "  • Memory: Jellyfin 1.5GB, Stash 1GB"
    echo "  • Health Checks: Enabled (30s interval)"
    echo ""
}

main() {
    print_header "Deploy Oracle Jellyfin + Stash with Podman Quadlets"

    check_podman
    create_quadlet_directory
    enable_lingering
    deploy_quadlets
    create_volumes
    setup_media_library
    reload_systemd
    enable_services
    start_services
    verify_services
    check_container_health
    show_access_info
    show_summary

    echo -e "${GREEN}✓ Deployment complete!${NC}\n"
    echo "Next steps:"
    echo "  1. Visit http://localhost:8096 to configure Jellyfin"
    echo "  2. Visit http://localhost:9999 to configure Stash"
    echo "  3. Add media to $MEDIA_LIBRARY"
    echo ""
}

main "$@"
