#!/bin/bash

##############################################################################
# Paperless Import Script
#
# Imports Stash deployment documentation into Paperless document management
#
# Usage:
#   ./import-paperless.sh https://paperless.example.com token_12345
#   PAPERLESS_URL=https://paperless.example.com \
#   PAPERLESS_TOKEN=token_12345 \
#   ./import-paperless.sh
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PAPERLESS_URL="${1:-${PAPERLESS_URL:-}}"
PAPERLESS_TOKEN="${2:-${PAPERLESS_TOKEN:-}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_DIR="${TEMP_DIR:-/tmp/paperless-import-$$}"

print_header() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Paperless Import - Stash Documentation           ║${NC}"
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

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

check_requirements() {
    print_section "Checking requirements"

    if ! command -v curl &> /dev/null; then
        print_error "curl not installed"
        exit 1
    fi
    print_success "curl available"

    if ! command -v pandoc &> /dev/null; then
        print_warning "pandoc not found - installing..."
        sudo apt-get update && sudo apt-get install -y pandoc >/dev/null 2>&1 || {
            print_warning "Could not install pandoc automatically"
            print_info "Install manually: sudo apt install pandoc"
        }
    fi
    print_success "pandoc available"

    # Check for wkhtmltopdf or other PDF converter
    if ! command -v wkhtmltopdf &> /dev/null && ! command -v pandoc &> /dev/null; then
        print_warning "No PDF converter found"
        print_info "Install wkhtmltopdf for better PDF quality: sudo apt install wkhtmltopdf"
    fi

    if [ -z "$PAPERLESS_URL" ] || [ -z "$PAPERLESS_TOKEN" ]; then
        print_error "Paperless URL and token required"
        echo ""
        echo "Usage:"
        echo "  $0 <paperless_url> <token>"
        echo ""
        echo "Or set environment variables:"
        echo "  export PAPERLESS_URL=https://paperless.example.com"
        echo "  export PAPERLESS_TOKEN=token_12345"
        echo "  $0"
        exit 1
    fi

    print_success "Configuration valid"
}

verify_connection() {
    print_section "Verifying Paperless connection"

    if ! curl -s -H "Authorization: Token $PAPERLESS_TOKEN" \
        "$PAPERLESS_URL/api/documents/" > /dev/null; then
        print_error "Failed to connect to Paperless"
        print_info "Check URL and token"
        exit 1
    fi

    print_success "Connected to Paperless"
}

get_or_create_tag() {
    local tag_name="$1"

    # Check if tag exists
    response=$(curl -s -H "Authorization: Token $PAPERLESS_TOKEN" \
        "$PAPERLESS_URL/api/tags/?name=$tag_name")

    tag_id=$(echo "$response" | jq -r '.results[0].id // empty' 2>/dev/null)

    if [ -z "$tag_id" ]; then
        # Create tag
        response=$(curl -s -X POST "$PAPERLESS_URL/api/tags/" \
            -H "Authorization: Token $PAPERLESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$tag_name\"}")

        tag_id=$(echo "$response" | jq -r '.id')
    fi

    echo "$tag_id"
}

convert_to_pdf() {
    local markdown_file="$1"
    local pdf_file="$2"

    print_info "Converting $markdown_file to PDF..."

    # Convert markdown to HTML, then HTML to PDF
    if command -v wkhtmltopdf &> /dev/null; then
        pandoc "$markdown_file" -f markdown -t html | \
            wkhtmltopdf - "$pdf_file" 2>/dev/null || {
            # Fallback to pandoc only
            pandoc "$markdown_file" -f markdown -t pdf -o "$pdf_file"
        }
    else
        pandoc "$markdown_file" -f markdown -t pdf -o "$pdf_file"
    fi

    if [ -f "$pdf_file" ]; then
        print_success "Created: $(basename "$pdf_file")"
    else
        print_error "Failed to create PDF from $markdown_file"
        return 1
    fi
}

upload_document() {
    local pdf_file="$1"
    local title="$2"
    shift 2
    local tags=("$@")

    print_info "Uploading: $title"

    # Build tag parameter
    local tag_ids=()
    for tag in "${tags[@]}"; do
        tag_id=$(get_or_create_tag "$tag")
        tag_ids+=("$tag_id")
    done

    # Build tags JSON array
    local tags_json="["
    for i in "${!tag_ids[@]}"; do
        tags_json+="${tag_ids[$i]}"
        if [ $i -lt $((${#tag_ids[@]} - 1)) ]; then
            tags_json+=","
        fi
    done
    tags_json+="]"

    # Upload document
    response=$(curl -s -X POST "$PAPERLESS_URL/api/documents/post_document/" \
        -H "Authorization: Token $PAPERLESS_TOKEN" \
        -F "document=@$pdf_file" \
        -F "title=$title" \
        -F "tags=$tags_json")

    if echo "$response" | jq . >/dev/null 2>&1; then
        doc_id=$(echo "$response" | jq -r '.id // empty')
        if [ -n "$doc_id" ]; then
            print_success "Uploaded: $title (ID: $doc_id)"
            return 0
        fi
    fi

    print_error "Failed to upload: $title"
    return 1
}

import_documentation() {
    print_section "Converting documentation to PDFs"

    mkdir -p "$TEMP_DIR"

    # Get tag IDs
    STASH_TAG=$(get_or_create_tag "stash")
    DEPLOYMENT_TAG=$(get_or_create_tag "deployment")
    DOCKER_TAG=$(get_or_create_tag "docker")
    PODMAN_TAG=$(get_or_create_tag "podman")
    GUIDE_TAG=$(get_or_create_tag "guide")

    print_success "Tags created/verified"

    print_section "Converting documents to PDF"

    # Create PDFs from markdown files
    declare -A files_to_upload

    files_to_upload["$REPO_DIR/QUICK_START_DEPLOYMENT.md"]="Stash Quick Start Deployment Guide"
    files_to_upload["$REPO_DIR/INSTALL_AND_DEPLOY.md"]="Stash Installation and Deployment"
    files_to_upload["$REPO_DIR/DEPLOYMENT_COMPARISON.md"]="Stash Deployment Methods Comparison"
    files_to_upload["$REPO_DIR/DEPLOY_GUIDE.md"]="Stash Deploy Script Guide"
    files_to_upload["$REPO_DIR/docs/bookstack/02-docker-deployment.md"]="Stash Docker Deployment Guide"
    files_to_upload["$REPO_DIR/docs/bookstack/03-podman-deployment.md"]="Stash Podman Deployment Guide"
    files_to_upload["$REPO_DIR/podman/QUADLET_SETUP.md"]="Stash Podman Quadlet Setup"
    files_to_upload["$REPO_DIR/podman/QUADLET_QUICK_START.md"]="Stash Podman Quadlet Quick Start"
    files_to_upload["$REPO_DIR/podman/TEMPLATE_USAGE.md"]="Stash Template System Usage"
    files_to_upload["$REPO_DIR/docs/1password/1PASSWORD_SETUP.md"]="Stash 1Password Integration Setup"
    files_to_upload["$REPO_DIR/docs/1password/QUICK_START.md"]="Stash 1Password Quick Start"

    print_section "Uploading documents"

    local uploaded=0
    local failed=0

    for markdown_file in "${!files_to_upload[@]}"; do
        if [ ! -f "$markdown_file" ]; then
            print_info "Skipping (not found): $markdown_file"
            continue
        fi

        title="${files_to_upload[$markdown_file]}"
        pdf_file="$TEMP_DIR/$(basename "$markdown_file" .md).pdf"

        if convert_to_pdf "$markdown_file" "$pdf_file"; then
            # Determine tags based on content
            local doc_tags=("stash" "deployment" "guide")

            if [[ "$markdown_file" == *"docker"* ]]; then
                doc_tags+=("docker")
            fi
            if [[ "$markdown_file" == *"podman"* ]]; then
                doc_tags+=("podman")
            fi
            if [[ "$markdown_file" == *"1password"* ]]; then
                doc_tags+=("security")
            fi
            if [[ "$markdown_file" == *"QUICK"* ]]; then
                doc_tags+=("quick-start")
            fi

            if upload_document "$pdf_file" "$title" "${doc_tags[@]}"; then
                ((uploaded++))
            else
                ((failed++))
            fi
        else
            ((failed++))
        fi
    done

    echo ""
    print_success "Upload complete: $uploaded documents"
    if [ $failed -gt 0 ]; then
        print_info "Failed: $failed documents"
    fi
}

show_summary() {
    echo ""
    print_section "Import Summary"
    echo "Paperless URL: $PAPERLESS_URL"
    echo "Documents uploaded: See Paperless web interface"
    echo ""
    echo "Next steps:"
    echo "  1. Visit $PAPERLESS_URL"
    echo "  2. Navigate to Documents"
    echo "  3. Filter by 'stash' tag to see all imported documents"
    echo "  4. Add notes and metadata as needed"
    echo ""
    echo "Tags created:"
    echo "  - stash: All Stash-related documents"
    echo "  - deployment: Deployment guides"
    echo "  - docker: Docker-related documents"
    echo "  - podman: Podman-related documents"
    echo "  - guide: Setup and configuration guides"
    echo "  - quick-start: Quick start guides"
    echo "  - security: Security-related documents"
    echo ""
}

main() {
    print_header

    check_requirements
    verify_connection
    import_documentation
    show_summary

    echo -e "${GREEN}✓ All done!${NC}\n"
}

main
