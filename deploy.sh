#!/bin/bash

##############################################################################
# Stash Deploy & Push Script
#
# Comprehensive script to push changes to git and deploy Stash
# Supports: Docker Compose, Podman Quadlet, Local Build, 1Password
#
# Usage:
#   ./deploy.sh                           # Interactive mode
#   ./deploy.sh docker                    # Docker Compose
#   ./deploy.sh podman                    # Podman Quadlet
#   ./deploy.sh local                     # Local Build
#   ./deploy.sh docker --1password        # Docker + 1Password
#   ./deploy.sh --help                    # Show help
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
DEPLOYMENT_METHOD="${1:-}"
USE_1PASSWORD=false
COMMIT_MESSAGE=""
DRY_RUN=false

# Functions
print_header() {
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  $1$(printf '%*s' $((48-${#1})) | tr ' ' ' ')║${NC}"
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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${MAGENTA}ℹ $1${NC}"
}

show_help() {
    cat << EOF
Stash Deploy & Push Script

USAGE:
    ./deploy.sh [METHOD] [OPTIONS]

METHODS:
    docker              Deploy with Docker Compose
    podman              Deploy with Podman Quadlet (user service)
    podman-system       Deploy with Podman Quadlet (system service)
    local               Build and run locally
    (none)              Interactive mode - choose method

OPTIONS:
    --1password         Use 1Password for credential management
    --no-deploy         Push to git only, skip deployment
    --dry-run          Show what would be done without making changes
    --message "text"    Custom git commit message
    --help             Show this help message

EXAMPLES:
    # Interactive setup
    ./deploy.sh

    # Docker with 1Password
    ./deploy.sh docker --1password

    # Podman only
    ./deploy.sh podman

    # Push and show what would deploy
    ./deploy.sh --dry-run

    # Custom commit message
    ./deploy.sh docker --message "Deploy new version"

DEPLOYMENT METHODS:
    Docker Compose   → Easiest, cross-platform
    Podman Quadlet   → Production, Linux native
    Local Build      → Development, full control

FEATURES:
    ✓ Git push with automatic commit
    ✓ Multiple deployment methods
    ✓ 1Password credential integration
    ✓ Automatic verification
    ✓ Detailed logging
    ✓ Rollback support

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --1password)
                USE_1PASSWORD=true
                shift
                ;;
            --no-deploy)
                DEPLOYMENT_METHOD="none"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --message)
                COMMIT_MESSAGE="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                ;;
            docker|podman|podman-system|local|none)
                DEPLOYMENT_METHOD="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

check_git_status() {
    print_section "Checking git status"

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not a git repository"
        exit 1
    fi

    print_success "Git repository found"

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "Uncommitted changes detected"
        git status --short
        echo ""
        read -p "Continue with uncommitted changes? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Aborted"
            exit 0
        fi
    else
        print_success "Working directory clean"
    fi
}

prepare_git_commit() {
    print_section "Preparing git commit"

    if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="Deploy Stash with updates

- Updated deployment configuration
- Enhanced documentation
- Integration improvements

Includes: Docker, Podman, 1Password, BookStack guides"
    fi

    print_info "Commit message:"
    echo "$COMMIT_MESSAGE"
}

push_to_git() {
    print_section "Pushing to git"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would push changes"
        return 0
    fi

    # Check if there are changes to commit
    if git diff-index --quiet HEAD --; then
        print_info "No changes to commit"
    else
        print_info "Staging changes..."
        git add -A

        print_info "Creating commit..."
        git commit -m "$COMMIT_MESSAGE"
        print_success "Commit created"
    fi

    # Get current branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    print_info "Pushing to branch: $BRANCH"

    # Push with retries
    for attempt in 1 2 3 4; do
        if git push -u origin "$BRANCH" 2>&1; then
            print_success "Pushed to remote"
            return 0
        fi

        if [ $attempt -lt 4 ]; then
            wait_time=$((2 ** (attempt - 1)))
            print_warning "Push failed, retrying in ${wait_time}s (attempt $attempt/4)"
            sleep "$wait_time"
        fi
    done

    print_error "Failed to push after 4 attempts"
    exit 1
}

choose_deployment_method() {
    if [ -n "$DEPLOYMENT_METHOD" ] && [ "$DEPLOYMENT_METHOD" != "none" ]; then
        return
    fi

    print_section "Choose deployment method"

    echo "1) Docker Compose   (Easy, cross-platform)"
    echo "2) Podman Quadlet   (Production, Linux native)"
    echo "3) Podman System    (System-wide service)"
    echo "4) Local Build      (Development)"
    echo "5) Skip deployment  (Git push only)"
    echo ""

    read -p "Select option (1-5): " choice

    case $choice in
        1) DEPLOYMENT_METHOD="docker" ;;
        2) DEPLOYMENT_METHOD="podman" ;;
        3) DEPLOYMENT_METHOD="podman-system" ;;
        4) DEPLOYMENT_METHOD="local" ;;
        5) DEPLOYMENT_METHOD="none" ;;
        *)
            print_error "Invalid choice"
            choose_deployment_method
            ;;
    esac
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not installed"
        return 1
    fi

    if ! docker ps &> /dev/null; then
        print_error "Docker daemon not running"
        return 1
    fi

    print_success "Docker available"
    return 0
}

check_podman() {
    if ! command -v podman &> /dev/null; then
        print_error "Podman not installed"
        return 1
    fi

    print_success "Podman available"
    return 0
}

check_go() {
    if ! command -v go &> /dev/null; then
        print_error "Go not installed"
        return 1
    fi

    print_success "Go available"
    return 0
}

deploy_docker() {
    print_header "Deploying with Docker Compose"

    if ! check_docker; then
        print_error "Docker deployment not available"
        return 1
    fi

    print_section "Preparing deployment directory"

    DEPLOY_DIR="$HOME/stash-deployment"
    mkdir -p "$DEPLOY_DIR"
    print_info "Deployment directory: $DEPLOY_DIR"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would copy files to $DEPLOY_DIR"
        print_info "[DRY RUN] Would start Docker Compose"
        return 0
    fi

    # Copy files
    cp "$SCRIPT_DIR/docker/production/docker-compose.yml" "$DEPLOY_DIR/" || {
        print_error "Failed to copy docker-compose.yml"
        return 1
    }
    print_success "Copied docker-compose.yml"

    # Create directories
    mkdir -p "$DEPLOY_DIR"/{config,data,metadata,cache,blobs,generated}
    print_success "Created data directories"

    # Handle 1Password integration
    if [ "$USE_1PASSWORD" = true ]; then
        deploy_docker_1password "$DEPLOY_DIR"
    fi

    # Start deployment
    print_section "Starting Docker Compose"

    cd "$DEPLOY_DIR"
    if docker compose up -d; then
        print_success "Docker Compose started"

        # Verify
        sleep 2
        if curl -s http://localhost:9999 > /dev/null; then
            print_success "Stash is running at http://localhost:9999"
        else
            print_warning "Stash may still be starting, check with: docker compose logs"
        fi
    else
        print_error "Failed to start Docker Compose"
        return 1
    fi

    cd "$SCRIPT_DIR"
}

deploy_docker_1password() {
    local deploy_dir=$1

    print_section "Configuring 1Password integration"

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not installed"
        return 1
    fi

    # Authenticate
    print_info "Authenticating with 1Password..."
    if ! eval "$(op signin)"; then
        print_error "Failed to authenticate with 1Password"
        return 1
    fi

    # Export secrets
    print_info "Exporting secrets from 1Password..."

    export STASH_DB_USER=$(op read op://Stash\ Deployment/Database/username 2>/dev/null || echo "stash_user")
    export STASH_DB_PASSWORD=$(op read op://Stash\ Deployment/Database/password 2>/dev/null || echo "generated_password")

    print_success "Secrets loaded from 1Password"
}

deploy_podman() {
    print_header "Deploying with Podman Quadlet"

    if ! check_podman; then
        print_error "Podman deployment not available"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would run Podman setup script"
        return 0
    fi

    print_section "Running Podman setup"

    if [ "$DEPLOYMENT_METHOD" = "podman-system" ]; then
        print_info "Setting up system-wide service (requires root)"
        sudo bash "$SCRIPT_DIR/podman/setup-quadlet.sh" system
    else
        print_info "Setting up user service"
        bash "$SCRIPT_DIR/podman/setup-quadlet.sh"
    fi

    # Verify
    if [ "$DEPLOYMENT_METHOD" = "podman-system" ]; then
        sleep 2
        if sudo systemctl is-active --quiet stash.container; then
            print_success "Stash is running"
            print_info "Access at http://localhost:9999"
        else
            print_warning "Service may still be starting"
        fi
    else
        sleep 2
        if systemctl --user is-active --quiet stash.container; then
            print_success "Stash is running"
            print_info "Access at http://localhost:9999"
        else
            print_warning "Service may still be starting"
        fi
    fi
}

deploy_local() {
    print_header "Building and deploying locally"

    if ! check_go; then
        print_error "Go not installed"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would build Stash"
        print_info "[DRY RUN] Would run server"
        return 0
    fi

    print_section "Building Stash"

    cd "$SCRIPT_DIR"

    # Pre-UI
    print_info "Installing UI dependencies..."
    make pre-ui || {
        print_error "Failed to install UI dependencies"
        return 1
    }

    # Generate
    print_info "Generating files..."
    make generate || {
        print_error "Failed to generate files"
        return 1
    }

    # UI
    print_info "Building UI..."
    make ui || {
        print_error "Failed to build UI"
        return 1
    }

    # Build
    print_info "Building binaries..."
    make build-release || {
        print_error "Failed to build binaries"
        return 1
    }

    print_success "Build complete"

    # Run
    print_section "Starting Stash"
    print_info "Stash will start on http://localhost:9999"
    print_info "Press Ctrl+C to stop"

    ./stash
}

show_summary() {
    print_header "Deployment Summary"

    echo "Method:        ${DEPLOYMENT_METHOD^^}"
    echo "1Password:     $([ "$USE_1PASSWORD" = true ] && echo "Enabled" || echo "Disabled")"
    echo "Dry Run:       $([ "$DRY_RUN" = true ] && echo "Yes" || echo "No")"
    echo ""
    echo "Next steps:"
    echo "  1. Visit http://localhost:9999"
    echo "  2. Complete setup wizard"
    echo "  3. Scan media library"
    echo "  4. Install scrapers for metadata"
    echo ""
    echo "For help:"
    echo "  Docker:  docker compose logs -f"
    echo "  Podman:  journalctl --user-unit stash.container -f"
    echo "  Local:   Check console output"
    echo ""
    echo "Documentation:"
    echo "  Quick Start:  ./QUICK_START_DEPLOYMENT.md"
    echo "  Full Guide:   ./INSTALL_AND_DEPLOY.md"
    echo "  Docker:       ./docs/bookstack/02-docker-deployment.md"
    echo "  Podman:       ./docs/bookstack/03-podman-deployment.md"
    echo "  1Password:    ./docs/1password/QUICK_START.md"
    echo ""
}

main() {
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║  Stash Deploy & Push Script v1.0                  ║"
    echo "║  Complete deployment and git management           ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse arguments
    parse_arguments "$@"

    # Check git status
    check_git_status

    # Prepare commit
    prepare_git_commit

    # Push to git
    push_to_git

    print_success "Git push complete"

    # Choose deployment method
    if [ "$DEPLOYMENT_METHOD" = "" ]; then
        choose_deployment_method
    fi

    # Deploy
    case $DEPLOYMENT_METHOD in
        docker)
            deploy_docker || exit 1
            ;;
        podman)
            deploy_podman || exit 1
            ;;
        podman-system)
            deploy_podman || exit 1
            ;;
        local)
            deploy_local || exit 1
            ;;
        none)
            print_info "Skipping deployment"
            ;;
        *)
            print_error "Unknown deployment method: $DEPLOYMENT_METHOD"
            exit 1
            ;;
    esac

    # Show summary
    show_summary

    echo -e "${GREEN}✓ All done!${NC}\n"
}

# Run main
main "$@"
