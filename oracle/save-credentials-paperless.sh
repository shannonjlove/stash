#!/bin/bash

##############################################################################
# Save Oracle Credentials to Paperless
#
# Creates credential documents and uploads to Paperless with tagging
#
# Usage:
#   ./save-credentials-paperless.sh <paperless_url> <token> <public_ip>
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
PUBLIC_IP="${3:-}"
TEMP_DIR="/tmp/oracle-credentials-$$"

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
    rm -rf "$TEMP_DIR"
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
        print_error "pandoc not installed"
        print_info "Install with: sudo apt install pandoc"
        exit 1
    fi
    print_success "pandoc available"

    if [ -z "$PAPERLESS_URL" ] || [ -z "$PAPERLESS_TOKEN" ]; then
        print_error "Paperless URL and token required"
        exit 1
    fi

    print_success "Configuration valid"
}

verify_connection() {
    print_section "Verifying Paperless connection"

    if ! curl -s -H "Authorization: Token $PAPERLESS_TOKEN" \
        "$PAPERLESS_URL/api/documents/" > /dev/null; then
        print_error "Cannot connect to Paperless"
        exit 1
    fi

    print_success "Connected to Paperless"
}

create_or_get_tag() {
    local tag_name="$1"

    # Try to get existing tag
    response=$(curl -s -H "Authorization: Token $PAPERLESS_TOKEN" \
        "$PAPERLESS_URL/api/tags/?name=$tag_name")

    tag_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

    if [ -z "$tag_id" ]; then
        # Create tag
        response=$(curl -s -X POST "$PAPERLESS_URL/api/tags/" \
            -H "Authorization: Token $PAPERLESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$tag_name\"}")
        tag_id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
    fi

    echo "$tag_id"
}

create_instance_credentials() {
    print_section "Creating instance credentials document"

    mkdir -p "$TEMP_DIR"

    # Create markdown document
    cat > "$TEMP_DIR/oracle-instance.md" << EOF
# Oracle Cloud Instance Access

**CONFIDENTIAL - SECURE STORAGE REQUIRED**

Date Created: $(date)

## Instance Details

- **Public IP:** $PUBLIC_IP
- **Instance User:** ubuntu
- **Instance Type:** VM.Standard.E2.1.Micro
- **Region:** us-phoenix-1
- **OS:** Ubuntu 22.04 LTS
- **Status:** Active

## Access Information

### SSH Access
\`\`\`bash
# Download private key from 1Password
# chmod 600 oracle-media-key.pem
ssh -i oracle-media-key.pem ubuntu@$PUBLIC_IP
\`\`\`

### Web Access
- **Jellyfin:** http://$PUBLIC_IP:8096
- **Stash:** http://$PUBLIC_IP:9999

### Important Ports
- Port 22: SSH
- Port 8096: Jellyfin
- Port 9999: Stash
- Port 80: HTTP (if reverse proxy configured)
- Port 443: HTTPS (if configured)

## Credentials

**IMPORTANT:** See 1Password for actual passwords

- Jellyfin Admin: [See 1Password vault "Oracle Media Servers"]
- Stash Admin: [See 1Password vault "Oracle Media Servers"]
- SSH Private Key: [See 1Password vault "Oracle Media Servers"]

## Network Configuration

### Firewall Rules

Inbound traffic allowed:
- TCP 22 (SSH)
- TCP 8096 (Jellyfin)
- TCP 9999 (Stash)

### Security Group

Configured via Oracle Cloud VCN Security Lists

## Emergency Access

If access is lost:

1. Check 1Password for SSH key
2. Use Oracle Console → Instances → Instance Details
3. Use System → Boot Volume Options → Image → Serial Connection
4. Or create new instance from backup

## Maintenance Schedule

- Weekly: Check services running
- Monthly: Backup verification
- Quarterly: Security updates
- Annually: Certificate renewal (if HTTPS configured)

---

**DO NOT share this document. Store securely.**
**All sensitive passwords stored in 1Password.**
EOF

    # Convert to PDF
    pandoc "$TEMP_DIR/oracle-instance.md" -o "$TEMP_DIR/oracle-instance.pdf" \
        -V geometry:margin=1in -V fontsize=11pt

    print_success "Created instance credentials document"

    # Upload to Paperless
    print_info "Uploading to Paperless..."

    # Get tag IDs
    TAG_ORACLE=$(create_or_get_tag "oracle-cloud")
    TAG_CRED=$(create_or_get_tag "credentials")
    TAG_ACCESS=$(create_or_get_tag "access")

    # Upload document
    curl -s -X POST "$PAPERLESS_URL/api/documents/post_document/" \
        -H "Authorization: Token $PAPERLESS_TOKEN" \
        -F "document=@$TEMP_DIR/oracle-instance.pdf" \
        -F "title=Oracle Cloud Instance Access" \
        -F "tags=[$TAG_ORACLE,$TAG_CRED,$TAG_ACCESS]" > /dev/null

    print_success "Uploaded to Paperless"
}

create_admin_passwords() {
    print_section "Creating admin passwords document"

    cat > "$TEMP_DIR/admin-passwords.md" << 'EOF'
# Admin Credentials - DO NOT SHARE

**CONFIDENTIAL - STORE SECURELY IN 1PASSWORD**

Generated: $(date)

## Service Passwords

### Jellyfin
- **URL:** http://$PUBLIC_IP:8096
- **Username:** admin
- **Password:** [Stored in 1Password - retrieve via CLI]
  ```bash
  op read op://Oracle\ Media\ Servers/Jellyfin\ Admin/password
  ```
- **Notes:**
  - Change on first access
  - Enable 2FA if supported
  - Create limited user accounts for other users

### Stash
- **URL:** http://$PUBLIC_IP:9999
- **Username:** admin
- **Password:** [Stored in 1Password - retrieve via CLI]
  ```bash
  op read op://Oracle\ Media\ Servers/Stash\ Admin/password
  ```
- **Notes:**
  - Change on first access
  - Configure API key if using remote access
  - Enable authentication if public access planned

## SSH Access

### Private Key Location
- Stored in 1Password: "Oracle SSH Private Key"
- Retrieve with:
  ```bash
  op read op://Oracle\ Media\ Servers/Oracle\ SSH\ Private\ Key/private\ key > ~/.ssh/oracle.pem
  chmod 600 ~/.ssh/oracle.pem
  ```

### SSH Command
```bash
ssh -i ~/.ssh/oracle.pem ubuntu@$PUBLIC_IP
```

## Password Management

### Change Frequency
- Admin Passwords: Every 90 days
- SSH Key: Rotate if compromised
- API Keys: Every 6 months

### Update Procedure
1. Change in application
2. Update in 1Password immediately
3. Update in Paperless within 24 hours
4. Update in KeePass if applicable

## Security Notes

- Never commit passwords to git
- Never send passwords via email
- Never share credentials outside organization
- Always use HTTPS in production
- Enable 2FA where available
- Rotate keys after any suspected compromise

## Backup Locations

- Primary: 1Password (cloud encrypted)
- Secondary: Paperless (this document)
- Tertiary: Personal vault (encrypted backup)

---

**Last Updated:** $(date)
**Storage Level:** Top Secret
**Access:** Admin Only
EOF

    # Convert to PDF
    pandoc "$TEMP_DIR/admin-passwords.md" -o "$TEMP_DIR/admin-passwords.pdf" \
        -V geometry:margin=1in -V fontsize=11pt

    print_success "Created admin passwords document"

    # Upload
    TAG_PASSWORDS=$(create_or_get_tag "passwords")
    TAG_SECRET=$(create_or_get_tag "secret")

    curl -s -X POST "$PAPERLESS_URL/api/documents/post_document/" \
        -H "Authorization: Token $PAPERLESS_TOKEN" \
        -F "document=@$TEMP_DIR/admin-passwords.pdf" \
        -F "title=Oracle Cloud Admin Passwords" \
        -F "tags=[$TAG_ORACLE,$TAG_PASSWORDS,$TAG_SECRET]" > /dev/null

    print_success "Uploaded admin passwords to Paperless"
}

create_ssh_backup() {
    print_section "Creating SSH key backup (optional)"

    print_info "Enter SSH private key for backup (optional)"
    print_info "Leave blank to skip - key will only be in 1Password"
    read -p "Path to SSH key file (or press Enter to skip): " SSH_KEY_PATH

    if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
        print_info "Skipping SSH key backup"
        return 0
    fi

    # Create encrypted backup
    cat > "$TEMP_DIR/ssh-backup.md" << EOF
# SSH Private Key Backup

**CRITICAL - ENCRYPT BEFORE STORAGE**

Key Created: $(date)

## Key Information
- Fingerprint: $(ssh-keygen -lf "$SSH_KEY_PATH" 2>/dev/null | awk '{print $2}')
- Key Type: $(grep "BEGIN" "$SSH_KEY_PATH" | head -1)

## Location
- Primary: 1Password - "Oracle SSH Private Key"
- Backup: This document (encrypted)

## Usage
\`\`\`bash
chmod 600 oracle-media-key.pem
ssh -i oracle-media-key.pem ubuntu@$PUBLIC_IP
\`\`\`

---

**DO NOT SHARE. ENCRYPT BEFORE STORING.**
**Key material redacted in standard backups.**
EOF

    pandoc "$TEMP_DIR/ssh-backup.md" -o "$TEMP_DIR/ssh-backup.pdf"

    TAG_KEYS=$(create_or_get_tag "keys")

    curl -s -X POST "$PAPERLESS_URL/api/documents/post_document/" \
        -H "Authorization: Token $PAPERLESS_TOKEN" \
        -F "document=@$TEMP_DIR/ssh-backup.pdf" \
        -F "title=Oracle SSH Key Backup Info" \
        -F "tags=[$TAG_ORACLE,$TAG_KEYS,$TAG_SECRET]" > /dev/null

    print_success "Created SSH key backup document"
}

show_paperless_tags() {
    print_section "Created Paperless Tags"

    echo ""
    echo "Filter documents by tags:"
    echo ""
    echo "  All Oracle documents:"
    echo "    Tag: oracle-cloud"
    echo ""
    echo "  All credentials:"
    echo "    Tag: credentials"
    echo ""
    echo "  All passwords:"
    echo "    Tag: passwords"
    echo ""
    echo "  All keys:"
    echo "    Tag: keys"
    echo ""
    echo "  Secret documents:"
    echo "    Tag: secret"
    echo ""
}

show_summary() {
    print_section "Summary"

    echo ""
    echo "Documents created and uploaded:"
    echo ""
    echo "  1. Oracle Cloud Instance Access"
    echo "     - Public IP and connection info"
    echo "     - Emergency access procedures"
    echo "     - Tags: oracle-cloud, credentials, access"
    echo ""
    echo "  2. Oracle Cloud Admin Passwords"
    echo "     - Service URLs and usernames"
    echo "     - Instructions for retrieving from 1Password"
    echo "     - Tags: oracle-cloud, passwords, secret"
    echo ""
    echo "  3. Oracle SSH Key Backup Info"
    echo "     - Key fingerprint and location"
    echo "     - Usage instructions"
    echo "     - Tags: oracle-cloud, keys, secret"
    echo ""
    echo "Access in Paperless:"
    echo "  URL: $PAPERLESS_URL"
    echo "  Search: 'oracle-cloud'"
    echo "  Filter by tags above"
    echo ""
    echo "Sensitive data stored in 1Password vault:"
    echo "  Vault: 'Oracle Media Servers'"
    echo "  Items:"
    echo "    - Oracle Instance Access"
    echo "    - Oracle SSH Private Key"
    echo "    - Jellyfin Admin"
    echo "    - Stash Admin"
    echo ""
}

main() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Save Oracle Credentials to Paperless${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"

    check_requirements
    verify_connection
    create_instance_credentials
    create_admin_passwords
    create_ssh_backup
    show_paperless_tags
    show_summary

    echo -e "${GREEN}✓ Credentials saved to Paperless!${NC}\n"
}

main "$@"
