#!/bin/bash

# Stash Podman Quadlet Setup Script
# Sets up Stash as a systemd service using Podman quadlets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_WIDE="${1:-false}"
QUADLET_TYPE="stash.container"
if [ "$SYSTEM_WIDE" = "system" ]; then
    QUADLET_TYPE="stash-system.container"
fi

# Functions
print_header() {
    echo -e "\n${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  $1$(printf '%*s' $((37-${#1})) | tr ' ' ' ')║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}\n"
}

print_info() {
    echo -e "${YELLOW}ℹ  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓  $1${NC}"
}

print_error() {
    echo -e "${RED}✗  $1${NC}"
}

print_step() {
    echo -e "${BLUE}→  $1${NC}"
}

check_podman() {
    print_step "Checking Podman installation..."

    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed"
        echo "   Install from: https://podman.io/docs/installation"
        exit 1
    fi

    local version=$(podman --version | awk '{print $3}')
    print_success "Podman $version is installed"

    # Check if version supports quadlets (4.4+)
    local major=$(echo $version | cut -d. -f1)
    local minor=$(echo $version | cut -d. -f2)
    if [ "$major" -lt 4 ] || ([ "$major" -eq 4 ] && [ "$minor" -lt 4 ]); then
        print_error "Podman 4.4+ required for quadlets (found $version)"
        exit 1
    fi

    print_success "Podman version supports quadlets"
}

check_systemd() {
    print_step "Checking systemd..."

    if ! command -v systemctl &> /dev/null; then
        print_error "systemd is not available"
        exit 1
    fi

    print_success "systemd is available"
}

setup_user_service() {
    print_header "Setting up User-level Service"

    # Create directories
    print_step "Creating directories..."
    mkdir -p ~/.config/containers/systemd
    mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}
    print_success "Directories created"

    # Copy quadlet
    print_step "Installing quadlet..."
    cp "$SCRIPT_DIR/quadlet/stash.container" ~/.config/containers/systemd/
    print_success "Quadlet installed to ~/.config/containers/systemd/"

    # Reload and enable
    print_step "Configuring systemd..."
    systemctl --user daemon-reload
    systemctl --user enable stash.container
    print_success "Service enabled for auto-start"

    # Start service
    print_step "Starting service..."
    systemctl --user start stash.container

    # Wait for container to start
    sleep 2

    # Check status
    if systemctl --user is-active --quiet stash.container; then
        print_success "Service started successfully!"
    else
        print_error "Service failed to start"
        echo ""
        print_info "Check logs with: journalctl --user-unit stash.container -n 20"
        exit 1
    fi
}

setup_system_service() {
    print_header "Setting up System-wide Service"

    if [ "$EUID" -ne 0 ]; then
        print_error "Root privileges required for system-wide setup"
        echo "   Run: sudo bash $0 system"
        exit 1
    fi

    # Create system user
    print_step "Creating system user..."
    if id stash &>/dev/null; then
        print_info "User 'stash' already exists"
    else
        useradd -r -s /sbin/nologin stash
        print_success "User 'stash' created"
    fi

    # Create directories
    print_step "Creating directories..."
    mkdir -p /etc/containers/systemd
    mkdir -p /etc/stash /var/lib/stash/{data,metadata,cache,blobs,generated}
    chown -R stash:stash /etc/stash /var/lib/stash
    chmod 750 /etc/stash /var/lib/stash
    print_success "Directories created and permissions set"

    # Copy quadlet
    print_step "Installing quadlet..."
    cp "$SCRIPT_DIR/quadlet/stash-system.container" /etc/containers/systemd/stash.container
    print_success "Quadlet installed to /etc/containers/systemd/"

    # Reload and enable
    print_step "Configuring systemd..."
    systemctl daemon-reload
    systemctl enable stash.container
    print_success "Service enabled for auto-start"

    # Start service
    print_step "Starting service..."
    systemctl start stash.container

    # Wait for container to start
    sleep 2

    # Check status
    if systemctl is-active --quiet stash.container; then
        print_success "Service started successfully!"
    else
        print_error "Service failed to start"
        echo ""
        print_info "Check logs with: sudo journalctl -u stash.container -n 20"
        exit 1
    fi
}

show_summary_user() {
    print_header "Setup Complete!"

    echo "Stash is now running as a user systemd service."
    echo ""
    echo "Access Stash:"
    echo -e "  ${BLUE}http://localhost:9999${NC}"
    echo ""
    echo "Useful commands:"
    echo "  Check status:     systemctl --user status stash.container"
    echo "  View logs:        journalctl --user-unit stash.container -f"
    echo "  Stop service:     systemctl --user stop stash.container"
    echo "  Restart service:  systemctl --user restart stash.container"
    echo ""
    echo "Data location:  ~/.stash/"
    echo ""
    echo "For more information, see: podman/QUADLET_SETUP.md"
}

show_summary_system() {
    print_header "Setup Complete!"

    echo "Stash is now running as a system-wide systemd service."
    echo ""
    echo "Access Stash:"
    echo -e "  ${BLUE}http://localhost:9999${NC}"
    echo ""
    echo "Useful commands:"
    echo "  Check status:     sudo systemctl status stash.container"
    echo "  View logs:        sudo journalctl -u stash.container -f"
    echo "  Stop service:     sudo systemctl stop stash.container"
    echo "  Restart service:  sudo systemctl restart stash.container"
    echo ""
    echo "Data location:  /var/lib/stash/"
    echo "Config location: /etc/stash/"
    echo ""
    echo "For more information, see: podman/QUADLET_SETUP.md"
}

show_help() {
    cat << EOF
Stash Podman Quadlet Setup Script

Usage: $(basename "$0") [OPTIONS]

OPTIONS:
    system      Setup as system-wide service (requires root)
    user        Setup as user service (default)
    help        Show this help message

EXAMPLES:
    # User-level setup (default)
    bash setup-quadlet.sh

    # System-wide setup (requires root)
    sudo bash setup-quadlet.sh system

EOF
    exit 0
}

# Main execution
main() {
    # Parse arguments
    case "${1:-user}" in
        system) SYSTEM_WIDE=true ;;
        user) SYSTEM_WIDE=false ;;
        help|-h|--help) show_help ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac

    # Header
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Stash Podman Quadlet Setup           ║"
    echo "║  v1.0                                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    # Prerequisites checks
    print_header "Checking Prerequisites"
    check_podman
    check_systemd
    echo ""

    # Setup
    if [ "$SYSTEM_WIDE" = "true" ]; then
        setup_system_service
        show_summary_system
    else
        setup_user_service
        show_summary_user
    fi

    echo ""
}

# Run main
main "$@"
