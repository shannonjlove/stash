#!/bin/bash

##############################################################################
# Unified Import Script
#
# Imports Stash documentation to BookStack, Paperless, or both
#
# Usage:
#   ./import-all.sh --bookstack <url> <token>
#   ./import-all.sh --paperless <url> <token>
#   ./import-all.sh --both <bookstack-url> <bookstack-token> <paperless-url> <paperless-token>
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "\n${MAGENTA}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║  Stash Documentation Import Tool                  ║"
    echo "║  Import to BookStack, Paperless, or both          ║"
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

show_help() {
    cat << EOF
Stash Documentation Import Tool

USAGE:
    ./import-all.sh [COMMAND] [OPTIONS]

COMMANDS:
    --bookstack <url> <token>
        Import documentation to BookStack

    --paperless <url> <token>
        Import documentation to Paperless

    --both <bs-url> <bs-token> <pl-url> <pl-token>
        Import documentation to both systems

    --help
        Show this help message

EXAMPLES:
    # Import to BookStack only
    ./import-all.sh --bookstack https://bookstack.example.com token_abc123

    # Import to Paperless only
    ./import-all.sh --paperless https://paperless.example.com token_abc123

    # Import to both (set tokens via environment variables)
    export BOOKSTACK_URL=https://bookstack.example.com
    export BOOKSTACK_TOKEN=token_abc123
    export PAPERLESS_URL=https://paperless.example.com
    export PAPERLESS_TOKEN=token_def456
    ./import-all.sh --both

    # Or provide all arguments
    ./import-all.sh --both https://bookstack.example.com token_abc123 \\
                          https://paperless.example.com token_def456

ENVIRONMENT VARIABLES:
    BOOKSTACK_URL       BookStack server URL
    BOOKSTACK_TOKEN     BookStack API token
    PAPERLESS_URL       Paperless server URL
    PAPERLESS_TOKEN     Paperless API token

EOF
    exit 0
}

check_script_exists() {
    local script="$1"
    if [ ! -f "$script" ]; then
        print_error "Script not found: $script"
        echo "Make sure you're running this from the scripts directory"
        exit 1
    fi
}

run_bookstack_import() {
    local url="$1"
    local token="$2"

    print_section "Starting BookStack import"
    print_info "Target: $url"

    check_script_exists "$SCRIPT_DIR/import-bookstack.sh"

    if bash "$SCRIPT_DIR/import-bookstack.sh" "$url" "$token"; then
        print_success "BookStack import completed successfully"
        return 0
    else
        print_error "BookStack import failed"
        return 1
    fi
}

run_paperless_import() {
    local url="$1"
    local token="$2"

    print_section "Starting Paperless import"
    print_info "Target: $url"

    check_script_exists "$SCRIPT_DIR/import-paperless.sh"

    if bash "$SCRIPT_DIR/import-paperless.sh" "$url" "$token"; then
        print_success "Paperless import completed successfully"
        return 0
    else
        print_error "Paperless import failed"
        return 1
    fi
}

main() {
    print_header

    local command="${1:-}"

    case "$command" in
        --bookstack)
            run_bookstack_import "${2:-$BOOKSTACK_URL}" "${3:-$BOOKSTACK_TOKEN}"
            ;;
        --paperless)
            run_paperless_import "${2:-$PAPERLESS_URL}" "${3:-$PAPERLESS_TOKEN}"
            ;;
        --both)
            local bs_url="${2:-$BOOKSTACK_URL}"
            local bs_token="${3:-$BOOKSTACK_TOKEN}"
            local pl_url="${4:-$PAPERLESS_URL}"
            local pl_token="${5:-$PAPERLESS_TOKEN}"

            run_bookstack_import "$bs_url" "$bs_token"
            BS_RESULT=$?

            run_paperless_import "$pl_url" "$pl_token"
            PL_RESULT=$?

            echo ""
            print_section "Summary"
            echo "BookStack:  $([ $BS_RESULT -eq 0 ] && echo "✓ Success" || echo "✗ Failed")"
            echo "Paperless:  $([ $PL_RESULT -eq 0 ] && echo "✓ Success" || echo "✗ Failed")"

            if [ $BS_RESULT -eq 0 ] && [ $PL_RESULT -eq 0 ]; then
                echo -e "\n${GREEN}All imports completed successfully!${NC}\n"
                exit 0
            else
                echo -e "\n${YELLOW}Some imports failed. Check logs above for details.${NC}\n"
                exit 1
            fi
            ;;
        --help|-h)
            show_help
            ;;
        "")
            print_error "No command specified"
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            ;;
    esac
}

main "$@"
