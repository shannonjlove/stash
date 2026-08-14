#!/bin/bash

##############################################################################
# BookStack Import Script
#
# Imports Stash deployment documentation into BookStack via REST API
#
# Usage:
#   ./import-bookstack.sh https://bookstack.example.com token_12345
#   BOOKSTACK_URL=https://bookstack.example.com \
#   BOOKSTACK_TOKEN=token_12345 \
#   ./import-bookstack.sh
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BOOKSTACK_URL="${1:-${BOOKSTACK_URL:-}}"
BOOKSTACK_TOKEN="${2:-${BOOKSTACK_TOKEN:-}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  BookStack Import - Stash Documentation           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}\n"
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

check_requirements() {
    print_section "Checking requirements"

    if ! command -v curl &> /dev/null; then
        print_error "curl not installed"
        exit 1
    fi
    print_success "curl available"

    if ! command -v jq &> /dev/null; then
        print_error "jq not installed (required for JSON parsing)"
        print_info "Install with: sudo apt install jq"
        exit 1
    fi
    print_success "jq available"

    if [ -z "$BOOKSTACK_URL" ] || [ -z "$BOOKSTACK_TOKEN" ]; then
        print_error "BookStack URL and token required"
        echo ""
        echo "Usage:"
        echo "  $0 <bookstack_url> <token>"
        echo ""
        echo "Or set environment variables:"
        echo "  export BOOKSTACK_URL=https://bookstack.example.com"
        echo "  export BOOKSTACK_TOKEN=token_12345"
        echo "  $0"
        exit 1
    fi

    print_success "Configuration valid"
}

verify_connection() {
    print_section "Verifying BookStack connection"

    if ! curl -s -H "Authorization: Token $BOOKSTACK_TOKEN" \
        "$BOOKSTACK_URL/api/shelves" > /dev/null; then
        print_error "Failed to connect to BookStack"
        print_info "Check URL and token"
        exit 1
    fi

    print_success "Connected to BookStack"
}

create_shelf() {
    local name="$1"
    local desc="$2"

    print_info "Creating shelf: $name"

    response=$(curl -s -X POST "$BOOKSTACK_URL/api/shelves" \
        -H "Authorization: Token $BOOKSTACK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$desc\"
        }")

    echo "$response" | jq -r '.id'
}

create_book() {
    local name="$1"
    local desc="$2"
    local shelf_id="$3"

    print_info "Creating book: $name"

    response=$(curl -s -X POST "$BOOKSTACK_URL/api/books" \
        -H "Authorization: Token $BOOKSTACK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$desc\"
        }")

    echo "$response" | jq -r '.id'
}

create_chapter() {
    local name="$1"
    local desc="$2"
    local book_id="$3"

    print_info "Creating chapter: $name"

    response=$(curl -s -X POST "$BOOKSTACK_URL/api/chapters" \
        -H "Authorization: Token $BOOKSTACK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$desc\",
            \"book_id\": $book_id
        }")

    echo "$response" | jq -r '.id'
}

create_page() {
    local name="$1"
    local content="$2"
    local book_id="$3"
    local chapter_id="${4:-0}"

    print_info "Creating page: $name"

    # Escape content for JSON
    content=$(echo "$content" | jq -Rs '.')

    response=$(curl -s -X POST "$BOOKSTACK_URL/api/pages" \
        -H "Authorization: Token $BOOKSTACK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"html\": $content,
            \"book_id\": $book_id,
            \"chapter_id\": $chapter_id
        }")

    echo "$response" | jq -r '.id'
}

markdown_to_html() {
    local markdown_file="$1"

    # Simple markdown to HTML conversion using pandoc if available
    if command -v pandoc &> /dev/null; then
        pandoc "$markdown_file" -f markdown -t html
    else
        # Fallback: simple conversion
        sed 's/^# /<h1>/; s/$/\n<\/h1>/' "$markdown_file"
    fi
}

import_documentation() {
    print_section "Creating Stash Documentation structure"

    # Create shelf
    print_info "Creating shelf..."
    SHELF_ID=$(create_shelf \
        "Stash Documentation" \
        "Complete guide for installing and deploying Stash media server")
    print_success "Shelf created (ID: $SHELF_ID)"

    # Book 1: Getting Started
    print_info "Creating 'Getting Started' book..."
    BOOK_1=$(create_book \
        "Getting Started" \
        "Quick start and comparison of deployment methods")

    # Add quick start page
    if [ -f "$REPO_DIR/QUICK_START_DEPLOYMENT.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/QUICK_START_DEPLOYMENT.md")
        create_page "Quick Start" "$content" "$BOOK_1"
    fi

    # Add deployment comparison
    if [ -f "$REPO_DIR/DEPLOYMENT_COMPARISON.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/DEPLOYMENT_COMPARISON.md")
        create_page "Deployment Methods" "$content" "$BOOK_1"
    fi

    # Add full installation guide
    if [ -f "$REPO_DIR/INSTALL_AND_DEPLOY.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/INSTALL_AND_DEPLOY.md")
        create_page "Complete Installation Guide" "$content" "$BOOK_1"
    fi

    print_success "Getting Started book created (ID: $BOOK_1)"

    # Book 2: Docker Deployment
    print_info "Creating 'Docker Deployment' book..."
    BOOK_2=$(create_book \
        "Docker Deployment" \
        "Docker and Docker Compose deployment guides")

    if [ -f "$REPO_DIR/docs/bookstack/02-docker-deployment.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/docs/bookstack/02-docker-deployment.md")
        create_page "Docker Compose Setup" "$content" "$BOOK_2"
    fi

    print_success "Docker Deployment book created (ID: $BOOK_2)"

    # Book 3: Podman Deployment
    print_info "Creating 'Podman Deployment' book..."
    BOOK_3=$(create_book \
        "Podman Deployment" \
        "Podman Quadlet and systemd integration")

    if [ -f "$REPO_DIR/docs/bookstack/03-podman-deployment.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/docs/bookstack/03-podman-deployment.md")
        create_page "Podman Quadlet Setup" "$content" "$BOOK_3"
    fi

    if [ -f "$REPO_DIR/podman/QUADLET_SETUP.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/podman/QUADLET_SETUP.md")
        create_page "Advanced Quadlet Configuration" "$content" "$BOOK_3"
    fi

    if [ -f "$REPO_DIR/podman/QUADLET_QUICK_START.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/podman/QUADLET_QUICK_START.md")
        create_page "Quick Start" "$content" "$BOOK_3"
    fi

    if [ -f "$REPO_DIR/podman/TEMPLATE_USAGE.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/podman/TEMPLATE_USAGE.md")
        create_page "Template System" "$content" "$BOOK_3"
    fi

    print_success "Podman Deployment book created (ID: $BOOK_3)"

    # Book 4: Advanced Features
    print_info "Creating 'Advanced Features' book..."
    BOOK_4=$(create_book \
        "Advanced Features" \
        "1Password integration and deployment automation")

    if [ -f "$REPO_DIR/docs/1password/1PASSWORD_SETUP.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/docs/1password/1PASSWORD_SETUP.md")
        create_page "1Password Integration" "$content" "$BOOK_4"
    fi

    if [ -f "$REPO_DIR/docs/1password/QUICK_START.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/docs/1password/QUICK_START.md")
        create_page "1Password Quick Start" "$content" "$BOOK_4"
    fi

    if [ -f "$REPO_DIR/DEPLOY_GUIDE.md" ]; then
        content=$(markdown_to_html "$REPO_DIR/DEPLOY_GUIDE.md")
        create_page "Deploy Script Guide" "$content" "$BOOK_4"
    fi

    print_success "Advanced Features book created (ID: $BOOK_4)"
}

main() {
    print_header

    check_requirements
    verify_connection
    import_documentation

    echo ""
    print_success "All documentation imported to BookStack!"
    echo ""
    echo "Next steps:"
    echo "  1. Visit $BOOKSTACK_URL"
    echo "  2. Navigate to 'Stash Documentation' shelf"
    echo "  3. Review and organize pages as needed"
    echo "  4. Add tags for easier discovery"
    echo ""
}

main
