# Oracle Cloud Deployment - BookStack Integration

Import Oracle Jellyfin + Stash deployment documentation to BookStack with secure credential storage.

## Overview

This integration stores:
- **BookStack:** Deployment guides, setup procedures, management commands
- **Paperless:** Access credentials and login information
- **1Password:** Sensitive credentials, SSH keys, API tokens

## Quick Setup

### 1. Import to BookStack

```bash
# From stash/oracle directory
./import-bookstack-oracle.sh \
  https://bookstack.example.com \
  your_api_token
```

Or with environment variables:
```bash
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=your_token
./import-bookstack-oracle.sh
```

### 2. Store Credentials in Paperless

```bash
# Save Oracle credentials to Paperless
./save-credentials-paperless.sh \
  https://paperless.example.com \
  your_token \
  YOUR_PUBLIC_IP
```

### 3. Store Secrets in 1Password

```bash
# Create 1Password vault and items
./setup-1password-oracle.sh

# Or manually:
# 1. Create vault: "Oracle Media Servers"
# 2. Add items:
#    - Oracle SSH Key
#    - Jellyfin Admin Password
#    - Stash Admin Password
#    - Instance Details
```

## BookStack Structure

### Shelf: "Oracle Cloud Media"

```
Shelf: Oracle Cloud Media
├── Book: Getting Started
│   ├── Chapter: Quick Start
│   │   ├── Page: 15-Minute Deployment
│   │   ├── Page: Instance Creation
│   │   └── Page: Docker Installation
│   └── Chapter: Architecture
│       ├── Page: System Design
│       ├── Page: Storage Options
│       └── Page: Cost Analysis
│
├── Book: Jellyfin Setup
│   ├── Chapter: Installation
│   │   ├── Page: Initial Setup
│   │   ├── Page: Add Libraries
│   │   └── Page: User Management
│   └── Chapter: Configuration
│       ├── Page: Streaming Settings
│       ├── Page: Metadata Configuration
│       └── Page: Transcoding
│
├── Book: Stash Setup
│   ├── Chapter: Installation
│   │   ├── Page: Setup Wizard
│   │   ├── Page: Database Configuration
│   │   └── Page: Library Pointing
│   └── Chapter: Configuration
│       ├── Page: Scrapers
│       ├── Page: Metadata Settings
│       └── Page: Organization
│
├── Book: Operations
│   ├── Chapter: Management
│   │   ├── Page: Service Commands
│   │   ├── Page: Monitoring
│   │   └── Page: Logs
│   └── Chapter: Maintenance
│       ├── Page: Backups
│       ├── Page: Updates
│       └── Page: Troubleshooting
│
└── Book: Advanced
    ├── Chapter: Storage
    │   ├── Page: Block Storage Setup
    │   └── Page: Media Management
    └── Chapter: Security
        ├── Page: SSH Configuration
        ├── Page: Firewall Rules
        └── Page: HTTPS Setup
```

## Paperless Organization

### Document Types

**Category: Oracle Infrastructure**
- Document: Oracle Instance Access (Credentials PDF)
- Document: SSH Key Backup
- Document: Instance Details

**Category: Jellyfin**
- Document: Admin Password
- Document: User Accounts List
- Document: API Keys

**Category: Stash**
- Document: Admin Password
- Document: Database Info
- Document: API Keys

### Tagging Strategy

```
Tags:
- oracle-cloud
- jellyfin
- stash
- credentials
- access
- passwords
- keys
- infrastructure
```

## 1Password Vault Structure

### Vault: "Oracle Media Servers"

#### Item: Oracle Instance Access
```
Category: Server
Fields:
- Public IP: YOUR_PUBLIC_IP
- Private IP: INSTANCE_IP
- Region: us-phoenix-1 (or your region)
- Username: ubuntu
- Instance ID: ocid1.instance.oc1...
```

#### Item: SSH Private Key
```
Category: Password
Fields:
- Key Name: oracle-media-key
- Private Key: [Full SSH private key text]
- Key Fingerprint: [fingerprint]
```

#### Item: Jellyfin Admin
```
Category: Login
Fields:
- URL: http://PUBLIC_IP:8096
- Username: admin
- Password: [strong password]
- Email: your@email.com
```

#### Item: Stash Admin
```
Category: Login
Fields:
- URL: http://PUBLIC_IP:9999
- Username: admin
- Password: [strong password]
- Security Code: [if 2FA enabled]
```

#### Item: Oracle API Credentials
```
Category: Password
Fields:
- Tenancy OCID: ocid1.tenancy...
- User OCID: ocid1.user...
- API Key: [private key]
- Fingerprint: [fingerprint]
```

#### Item: 1Password Integration
```
Category: Login
Fields:
- Vault Name: "Oracle Media Servers"
- Token Type: Personal Access Token
- Token: [token from 1Password]
```

## Integration Workflow

### New Oracle Deployment

1. **Create Instance**
   - Note public IP
   - Save SSH key

2. **Add to 1Password**
   ```bash
   op item create --category server \
     --title "Oracle Media Instance" \
     --vault "Oracle Media Servers" \
     hostname=YOUR_PUBLIC_IP \
     username=ubuntu
   ```

3. **Deploy Services**
   ```bash
   ./deploy-oracle.sh
   ```

4. **Set Admin Passwords**
   - Jellyfin: Set via web UI
   - Stash: Set via web UI

5. **Save to 1Password**
   ```bash
   op item create --category login \
     --title "Jellyfin Admin" \
     --vault "Oracle Media Servers" \
     url="http://IP:8096" \
     username=admin \
     password='[generated password]'
   ```

6. **Import to BookStack**
   ```bash
   ./import-bookstack-oracle.sh
   ```

7. **Save Credentials to Paperless**
   - Scan or upload credential documents
   - Tag with "oracle-cloud", "credentials"
   - Store admin passwords as secure PDFs

## Authentication & Access

### Get Credentials from 1Password

```bash
# List available items
op item list --vault "Oracle Media Servers"

# Get specific credential
op read op://Oracle\ Media\ Servers/Oracle\ Instance\ Access/public_ip

# Get Jellyfin password
op read op://Oracle\ Media\ Servers/Jellyfin\ Admin/password

# Get SSH key
op read op://Oracle\ Media\ Servers/SSH\ Private\ Key/private_key
```

### Access Documentation

**BookStack:**
```
1. Visit: https://bookstack.example.com
2. Search: "Oracle Cloud"
3. Browse: "Oracle Cloud Media" shelf
4. Use guide for procedures
```

**Paperless:**
```
1. Visit: https://paperless.example.com
2. Filter by tag: "oracle-cloud"
3. Search: "credentials" or "password"
4. View credential documents
```

**1Password:**
```bash
# Unlock vault
eval $(op signin)

# View saved credentials
op item list --vault "Oracle Media Servers"
```

## Credential Security Best Practices

### 1Password

✓ Use strong, unique passwords for all services  
✓ Enable 2FA on 1Password account  
✓ Use personal access tokens (not main password)  
✓ Rotate credentials periodically  
✓ Keep SSH keys backed up securely  

### Paperless

✓ Encrypt sensitive documents  
✓ Restrict access to credential documents  
✓ Use consistent tagging  
✓ Archive old credentials  
✓ Don't share PDFs directly  

### BookStack

✓ Restrict access to Operations/Advanced books  
✓ Don't include actual passwords in guides  
✓ Reference 1Password for credentials  
✓ Use placeholders in procedures  
✓ Audit access logs  

## Integration Scripts

### import-bookstack-oracle.sh

```bash
#!/bin/bash
# Import Oracle deployment docs to BookStack

BOOKSTACK_URL="${1:-${BOOKSTACK_URL:-}}"
BOOKSTACK_TOKEN="${2:-${BOOKSTACK_TOKEN:-}}"

# Create shelf
curl -X POST "$BOOKSTACK_URL/api/shelves" \
  -H "Authorization: Token $BOOKSTACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Oracle Cloud Media",
    "description": "Jellyfin and Stash deployment guides"
  }'

# Create books and pages for each guide
# ... implementation details ...
```

### save-credentials-paperless.sh

```bash
#!/bin/bash
# Save Oracle credentials to Paperless

PAPERLESS_URL="${1:-${PAPERLESS_URL:-}}"
PAPERLESS_TOKEN="${2:-${PAPERLESS_TOKEN:-}}"
PUBLIC_IP="${3:-}"

# Create credentials document
# Convert credentials to PDF
# Upload to Paperless with tags

pandoc -t pdf <<EOF > oracle-credentials.pdf
# Oracle Cloud Instance Access

**Instance Details**
- Public IP: $PUBLIC_IP
- Instance User: ubuntu
- Region: us-phoenix-1

**Access Methods**
- SSH: ssh -i key.pem ubuntu@$PUBLIC_IP
- Jellyfin: http://$PUBLIC_IP:8096
- Stash: http://$PUBLIC_IP:9999

**Passwords**
- Jellyfin Admin: [See 1Password]
- Stash Admin: [See 1Password]
EOF

# Upload
curl -X POST "$PAPERLESS_URL/api/documents/post_document/" \
  -H "Authorization: Token $PAPERLESS_TOKEN" \
  -F "document=@oracle-credentials.pdf" \
  -F "title=Oracle Cloud Credentials" \
  -F "tags=[oracle-cloud, credentials, access]"
```

### setup-1password-oracle.sh

```bash
#!/bin/bash
# Setup 1Password vault and items for Oracle deployment

# Create vault
op vault create "Oracle Media Servers" \
  --description "Oracle Cloud media server credentials"

# Create items
op item create --category server \
  --title "Oracle Instance Access" \
  --vault "Oracle Media Servers" \
  "Instance ID"=ocid1.instance.oc1...

op item create --category login \
  --title "Jellyfin Admin" \
  --vault "Oracle Media Servers" \
  url="http://YOUR_IP:8096" \
  username=admin

op item create --category login \
  --title "Stash Admin" \
  --vault "Oracle Media Servers" \
  url="http://YOUR_IP:9999" \
  username=admin
```

## Access Control Matrix

| System | Who | Purpose | Access |
|--------|-----|---------|--------|
| BookStack | Team | Read guides, procedures | Read-only |
| Paperless | Admins | Credential storage | Full access |
| 1Password | Admins | Secret management | Full access |

## Sync & Updates

### When to Update

- After password changes
- After instance upgrades
- After migration to new instance
- After security incidents

### Update Procedure

1. **Update 1Password**
   ```bash
   op item edit "Oracle Instance Access" \
     password="new_password"
   ```

2. **Update Paperless**
   - Edit credential document
   - Mark old as archived
   - Upload new version

3. **Update BookStack**
   - Modify guide if needed
   - Note changes in changelog
   - Publish updated version

## Disaster Recovery

### Credential Recovery

If access is lost:

1. **From 1Password**
   ```bash
   # Access via 1Password.com
   # Retrieve credentials from backup
   # Verify on new device
   ```

2. **From Paperless**
   ```bash
   # Export credential PDFs
   # Create new 1Password items
   # Verify consistency
   ```

3. **From SSH Key Backup**
   ```bash
   # SSH key stored in 1Password
   # SSH key backed up to Paperless
   # Use to recover access if needed
   ```

### Full Recovery

If instance is lost:

1. **Get credentials from 1Password**
   - Instance details
   - SSH key
   - Admin passwords

2. **Create new instance**
   - Use same OS image
   - Deploy services
   - Restore from backups

3. **Verify in BookStack**
   - Update IP address
   - Test procedures
   - Verify all services

## Monitoring & Alerts

### 1Password Monitoring

```bash
# Check activity log
op activity list --vault "Oracle Media Servers"

# Monitor access
# Enable 1Password Security Dashboard
# Set alerts for unusual access patterns
```

### Paperless Monitoring

```bash
# Check document access logs
# Monitor credential document views
# Alert on unauthorized access attempts
```

### BookStack Monitoring

```bash
# Check page access logs
# Monitor changes to guides
# Track edits and revisions
```

## Compliance & Audit

### Documentation Retention

- BookStack: Keep indefinitely
- Paperless: Archive after 1 year
- 1Password: Keep current credentials

### Access Audit

Monthly review:
- Who accessed credentials?
- When were they accessed?
- Any unauthorized attempts?

### Credential Rotation

Quarterly:
- Change admin passwords
- Rotate API keys
- Update in all systems

## Testing

### Verify Integration

```bash
# Test BookStack access
curl -s https://bookstack.example.com/api/books \
  -H "Authorization: Token $BOOKSTACK_TOKEN" | jq .

# Test Paperless access
curl -s https://paperless.example.com/api/documents/ \
  -H "Authorization: Token $PAPERLESS_TOKEN" | jq .

# Test 1Password access
eval $(op signin)
op item list --vault "Oracle Media Servers"
```

### Test Credential Retrieval

```bash
# Get Oracle IP
op read op://Oracle\ Media\ Servers/Oracle\ Instance\ Access/public_ip

# Get SSH Key
op read op://Oracle\ Media\ Servers/SSH\ Private\ Key/private_key > /tmp/oracle.pem
chmod 600 /tmp/oracle.pem

# SSH to instance
ssh -i /tmp/oracle.pem ubuntu@$(op read op://Oracle\ Media\ Servers/Oracle\ Instance\ Access/public_ip)
```

## References

- [1Password CLI Reference](https://developer.1password.com/docs/cli/)
- [Paperless API Docs](https://paperlessproject.org/api/)
- [BookStack API Reference](https://demo.bookstackapp.com/api/docs)

---

**Version:** 1.0  
**Last Updated:** 2026-07-25
