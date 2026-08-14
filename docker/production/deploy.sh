#!/bin/bash

# Stash Docker Deployment Script
# This script helps set up and deploy Stash using Docker Compose

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="${1:-.}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Please install Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    print_success "Docker is installed"
}

check_docker_compose() {
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose is available"
}

setup_directories() {
    print_header "Setting up directories"

    cd "$DEPLOYMENT_DIR"

    mkdir -p config data metadata cache blobs generated
    print_success "Created required directories"
}

copy_docker_compose() {
    print_header "Setting up Docker Compose configuration"

    if [ ! -f "$DEPLOYMENT_DIR/docker-compose.yml" ]; then
        cp "$SCRIPT_DIR/docker-compose.yml" "$DEPLOYMENT_DIR/"
        print_success "Copied docker-compose.yml"
    else
        print_info "docker-compose.yml already exists"
    fi
}

create_env_file() {
    print_header "Setting up environment configuration"

    if [ ! -f "$DEPLOYMENT_DIR/.env" ]; then
        cat > "$DEPLOYMENT_DIR/.env" << EOF
# Stash Configuration
STASH_PORT=9999
TZ=Etc/UTC

# Docker image version (latest, develop, or specific version)
STASH_VERSION=latest
EOF
        print_success "Created .env file"
        print_info "Edit .env to customize configuration"
    else
        print_info ".env already exists"
    fi
}

show_summary() {
    print_header "Deployment Ready"

    echo "Stash has been configured for Docker deployment!"
    echo ""
    echo "To start Stash:"
    echo "  cd $DEPLOYMENT_DIR"
    echo "  docker compose up -d"
    echo ""
    echo "To view logs:"
    echo "  docker compose logs -f"
    echo ""
    echo "To stop Stash:"
    echo "  docker compose down"
    echo ""
    echo "Access Stash at: http://localhost:9999"
    echo ""
    echo "Configuration files:"
    echo "  - config/        - Stash configuration"
    echo "  - data/          - Your media collection"
    echo "  - metadata/      - Scraped metadata"
    echo "  - generated/     - Generated content (previews, etc.)"
    echo "  - cache/         - Cache files"
    echo "  - blobs/         - Binary data (thumbnails, etc.)"
    echo ""
}

# Main execution
main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Stash Docker Deployment Setup        ║"
    echo "║  v1.0                                 ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    print_info "Deployment directory: $DEPLOYMENT_DIR"
    echo ""

    # Checks
    print_header "Checking requirements"
    check_docker
    check_docker_compose

    # Setup
    setup_directories
    copy_docker_compose
    create_env_file

    # Summary
    show_summary
}

# Run main function
main "$@"
