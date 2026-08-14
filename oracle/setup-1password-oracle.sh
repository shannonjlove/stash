#!/bin/bash

##############################################################################
# Setup 1Password Vault for Oracle Cloud Deployment
#
# Creates vault and items for storing Oracle instance credentials
#
# Usage:
#   ./setup-1password-oracle.sh <public_ip> <admin_password>
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PUBLIC_IP="${1:-}"
JELLYFIN_PASS="${2:-}"
STASH_PASS="${3:-}"
VAULT_NAME="Oracle Media Servers"

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

check_1password() {
    print_section "Checking 1Password CLI"

    if ! command -v op &> /dev/null; then
        print_error "1Password CLI not installed"
        print_info "Install from: https://developer.1password.com/docs/cli/get-started"
        exit 1
    fi

    print_success "1Password CLI found"

    # Check authentication
    if ! op user get --me &> /dev/null; then
        print_info "Signing in to 1Password..."
        eval $(op signin)
    fi

    print_success "Authenticated with 1Password"
}

create_vault() {
    print_section "Creating vault"

    # Check if vault exists
    if op vault get "$VAULT_NAME" &> /dev/null; then
        print_info "Vault '$VAULT_NAME' already exists"
        return 0
    fi

    # Create vault
    op vault create "$VAULT_NAME" \
        --description "Oracle Cloud Jellyfin and Stash credentials"

    print_success "Created vault: $VAULT_NAME"
}

create_instance_item() {
    print_section "Creating instance access item"

    if [ -z "$PUBLIC_IP" ]; then
        print_error "Public IP required"
        read -p "Enter public IP: " PUBLIC_IP
    fi

    # Create item
    op item create \
        --category server \
        --title "Oracle Instance Access" \
        --vault "$VAULT_NAME" \
        hostname="$PUBLIC_IP" \
        username="ubuntu" \
        "instance_type"="VM.Standard.E2.1.Micro" \
        region="us-phoenix-1" \
        os="Ubuntu 22.04 LTS"

    print_success "Created instance access item"
    echo ""
    echo "Access with: ssh -i oracle-key.pem ubuntu@$PUBLIC_IP"
}

create_ssh_key_item() {
    print_section "Creating SSH key item"

    print_info "Enter SSH private key (paste full key, then Ctrl+D on new line)"
    print_info "Or press Enter to skip (you can add later)"

    read -p "Paste SSH key or press Enter to skip: " SSH_KEY

    if [ -z "$SSH_KEY" ]; then
        print_info "Skipping SSH key (add manually to 1Password)"
        return 0
    fi

    # Create item
    op item create \
        --category password \
        --title "Oracle SSH Private Key" \
        --vault "$VAULT_NAME" \
        "private key=$SSH_KEY" \
        "key name"="oracle-media-key"

    print_success "Saved SSH key to 1Password"
}

create_jellyfin_item() {
    print_section "Creating Jellyfin admin item"

    if [ -z "$JELLYFIN_PASS" ]; then
        print_info "Enter Jellyfin admin password"
        read -sp "Password: " JELLYFIN_PASS
        echo ""
    fi

    op item create \
        --category login \
        --title "Jellyfin Admin" \
        --vault "$VAULT_NAME" \
        url="http://$PUBLIC_IP:8096" \
        username="admin" \
        password="$JELLYFIN_PASS" \
        email="admin@example.com"

    print_success "Saved Jellyfin admin credentials"
}

create_stash_item() {
    print_section "Creating Stash admin item"

    if [ -z "$STASH_PASS" ]; then
        print_info "Enter Stash admin password"
        read -sp "Password: " STASH_PASS
        echo ""
    fi

    op item create \
        --category login \
        --title "Stash Admin" \
        --vault "$VAULT_NAME" \
        url="http://$PUBLIC_IP:9999" \
        username="admin" \
        password="$STASH_PASS"

    print_success "Saved Stash admin credentials"
}

create_oracle_api_item() {
    print_section "Creating Oracle Cloud API credentials (optional)"

    print_info "Enter Oracle Cloud API credentials (or skip)"
    read -p "Tenancy OCID (or press Enter to skip): " TENANCY_OCID

    if [ -z "$TENANCY_OCID" ]; then
        print_info "Skipping Oracle API credentials"
        return 0
    fi

    read -p "User OCID: " USER_OCID
    read -sp "API Key Fingerprint: " API_FINGERPRINT
    echo ""

    op item create \
        --category password \
        --title "Oracle API Credentials" \
        --vault "$VAULT_NAME" \
        "tenancy OCID"="$TENANCY_OCID" \
        "user OCID"="$USER_OCID" \
        "api key fingerprint"="$API_FINGERPRINT"

    print_success "Saved Oracle API credentials"
}

show_access_methods() {
    print_section "Access Methods"

    echo ""
    echo "Access your credentials from 1Password:"
    echo ""
    echo "View all items:"
    echo "  op item list --vault \"$VAULT_NAME\""
    echo ""
    echo "Get instance IP:"
    echo "  op read op://$VAULT_NAME/Oracle\\ Instance\\ Access/hostname"
    echo ""
    echo "Get Jellyfin password:"
    echo "  op read op://$VAULT_NAME/Jellyfin\\ Admin/password"
    echo ""
    echo "Get Stash password:"
    echo "  op read op://$VAULT_NAME/Stash\\ Admin/password"
    echo ""
    echo "Get SSH key:"
    echo "  op read op://$VAULT_NAME/Oracle\\ SSH\\ Private\\ Key/private\\ key"
    echo ""
    echo "SSH to instance:"
    echo "  ssh -i <key_file> ubuntu@\$(op read op://$VAULT_NAME/Oracle\\ Instance\\ Access/hostname)"
    echo ""
}

main() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  1Password Setup - Oracle Cloud Deployment${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"

    check_1password
    create_vault
    create_instance_item
    create_ssh_key_item
    create_jellyfin_item
    create_stash_item
    create_oracle_api_item
    show_access_methods

    echo -e "${GREEN}✓ 1Password setup complete!${NC}\n"
    echo "Your credentials are now safely stored in 1Password."
    echo "You can access them from any device using the 1Password CLI or app."
    echo ""
}

main "$@"
