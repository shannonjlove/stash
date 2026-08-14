#!/bin/bash

##############################################################################
# Oracle Cloud Deployment Script
#
# Deploy Jellyfin and Stash to Oracle Cloud Always Free instance
# Ensures always-on operation with persistent storage
#
# Usage:
#   ./deploy-oracle.sh
#   ./deploy-oracle.sh --block-storage /mnt/media
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="/home/ubuntu/media-services"
BLOCK_STORAGE="${1:-}"

# Functions
print_header() {
    echo -e "\n${MAGENTA}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║  Oracle Cloud Deployment                          ║"
    echo "║  Jellyfin + Stash (Always-On)                     ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
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

check_prerequisites() {
    print_section "Checking prerequisites"

    # Check if running on Linux
    if [[ ! "$OSTYPE" == "linux"* ]]; then
        print_error "This script must run on Linux"
        exit 1
    fi
    print_success "Linux detected"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        print_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        print_success "Docker installed"
    else
        print_success "Docker installed"
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose not installed"
        exit 1
    fi
    print_success "Docker Compose available"

    # Check Docker daemon
    if ! docker ps &> /dev/null; then
        print_error "Docker daemon not accessible"
        print_info "Add current user to docker group:"
        echo "  sudo usermod -aG docker \$USER"
        echo "  newgrp docker"
        exit 1
    fi
    print_success "Docker daemon running"
}

setup_directories() {
    print_section "Setting up directories"

    # Create deployment directory
    mkdir -p "$DEPLOY_DIR"
    print_success "Created $DEPLOY_DIR"

    # Create media directories
    mkdir -p "$DEPLOY_DIR/jellyfin/config"
    mkdir -p "$DEPLOY_DIR/jellyfin/cache"
    mkdir -p "$DEPLOY_DIR/jellyfin/movies"
    mkdir -p "$DEPLOY_DIR/jellyfin/tv"
    mkdir -p "$DEPLOY_DIR/jellyfin/music"
    print_success "Created Jellyfin directories"

    mkdir -p "$DEPLOY_DIR/stash/config"
    mkdir -p "$DEPLOY_DIR/stash/data"
    print_success "Created Stash directories"

    # Set permissions
    chmod 755 "$DEPLOY_DIR"
    print_success "Set directory permissions"
}

setup_block_storage() {
    local mount_point="${BLOCK_STORAGE:-}"

    if [ -z "$mount_point" ]; then
        print_info "Block storage not configured (using boot volume)"
        return 0
    fi

    print_section "Configuring block storage"

    if [ ! -d "$mount_point" ]; then
        print_error "Mount point $mount_point does not exist"
        print_info "Create it with:"
        echo "  sudo mkdir -p $mount_point"
        echo "  sudo mount /dev/sdb1 $mount_point"
        return 1
    fi

    print_success "Block storage mounted at $mount_point"

    # Create media directories on block storage
    mkdir -p "$mount_point/jellyfin/movies"
    mkdir -p "$mount_point/jellyfin/tv"
    mkdir -p "$mount_point/stash-content"
    print_success "Created media directories on block storage"
}

setup_swap() {
    print_section "Setting up swap (prevents OOM)"

    # Check if swap already exists
    if grep -q "/swapfile" /etc/fstab; then
        print_info "Swap already configured"
        return 0
    fi

    # Create swap file
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # Make permanent
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

    print_success "Created 2GB swap file"
}

copy_docker_compose() {
    print_section "Setting up Docker Compose"

    # Copy docker-compose.yml
    cp "$SCRIPT_DIR/docker-compose.yml" "$DEPLOY_DIR/"
    print_success "Copied docker-compose.yml"

    # Adjust paths if block storage provided
    if [ -n "$BLOCK_STORAGE" ]; then
        sed -i "s|/home/ubuntu/jellyfin|$BLOCK_STORAGE/jellyfin|g" "$DEPLOY_DIR/docker-compose.yml"
        sed -i "s|/home/ubuntu/stash-content|$BLOCK_STORAGE/stash-content|g" "$DEPLOY_DIR/docker-compose.yml"
        print_success "Configured paths for block storage"
    fi
}

start_services() {
    print_section "Starting services"

    cd "$DEPLOY_DIR"

    # Pull images
    print_info "Pulling Docker images..."
    docker compose pull

    # Start services
    print_info "Starting containers..."
    docker compose up -d

    # Wait for services to be healthy
    print_info "Waiting for services to be healthy..."
    sleep 10

    # Check status
    if docker compose ps | grep -q "healthy"; then
        print_success "Services started successfully"
    else
        print_info "Services may still be starting (check logs)"
    fi

    cd "$SCRIPT_DIR"
}

setup_systemd_services() {
    print_section "Setting up systemd services for always-on"

    # Create systemd service for docker-compose
    sudo tee /etc/systemd/system/media-services.service > /dev/null << EOF
[Unit]
Description=Media Services (Jellyfin + Stash)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$USER
WorkingDirectory=$DEPLOY_DIR
ExecStart=$(which docker) compose up -d
ExecStop=$(which docker) compose down
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    print_success "Created systemd service"

    # Enable service
    sudo systemctl daemon-reload
    sudo systemctl enable media-services
    print_success "Service enabled for auto-start"

    # Enable user lingering (services persist after logout)
    loginctl enable-linger $USER
    print_success "User lingering enabled"
}

show_status() {
    print_section "Service Status"

    echo ""
    cd "$DEPLOY_DIR"
    docker compose ps
    cd "$SCRIPT_DIR"

    echo ""
}

show_next_steps() {
    print_section "Next Steps"

    # Get local IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    PUBLIC_IP=$(curl -s https://api.ipify.org || echo "YOUR_PUBLIC_IP")

    echo ""
    echo "Services are starting. Access them at:"
    echo ""
    echo "  Jellyfin:  http://$PUBLIC_IP:8096/web/index.html"
    echo "  Stash:     http://$PUBLIC_IP:9999"
    echo ""
    echo "Or locally from the instance:"
    echo ""
    echo "  Jellyfin:  http://$LOCAL_IP:8096/web/index.html"
    echo "  Stash:     http://$LOCAL_IP:9999"
    echo ""
    echo "Manage services:"
    echo ""
    echo "  View logs:       docker compose -f $DEPLOY_DIR/docker-compose.yml logs -f"
    echo "  Check status:    docker compose -f $DEPLOY_DIR/docker-compose.yml ps"
    echo "  Stop services:   docker compose -f $DEPLOY_DIR/docker-compose.yml down"
    echo "  Restart:         systemctl restart media-services"
    echo ""
    echo "First run setup:"
    echo ""
    echo "  Jellyfin:"
    echo "    1. Visit http://$PUBLIC_IP:8096"
    echo "    2. Configure language and region"
    echo "    3. Add media libraries (point to /media/movies, /media/tv, etc)"
    echo "    4. Configure playback settings"
    echo ""
    echo "  Stash:"
    echo "    1. Visit http://$PUBLIC_IP:9999"
    echo "    2. Complete the setup wizard"
    echo "    3. Point to your content library"
    echo "    4. Configure scrapers"
    echo ""
    echo "Persistent operation:"
    echo ""
    echo "  Services will automatically restart if they crash"
    echo "  Services will start on system reboot"
    echo "  Check status: systemctl status media-services"
    echo ""
}

main() {
    print_header

    check_prerequisites
    setup_directories
    setup_block_storage
    setup_swap
    copy_docker_compose
    start_services
    setup_systemd_services
    show_status
    show_next_steps

    echo -e "${GREEN}✓ Deployment complete!${NC}\n"
}

main "$@"
