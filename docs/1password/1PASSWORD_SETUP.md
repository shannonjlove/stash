# 1Password Integration with Stash Deployment

Secure your Stash deployment credentials and secrets using 1Password.

## Overview

Integrate 1Password with Stash to:
- ✅ Manage database credentials securely
- ✅ Store API keys and tokens
- ✅ Manage scraper credentials
- ✅ Secure reverse proxy passwords
- ✅ Automate credential injection
- ✅ Share credentials with team members

## Prerequisites

- 1Password account (Business or Team account required for 1Password CLI)
- 1Password CLI installed
- Docker or Podman for Stash
- Access to deployment environment

## Installation

### 1Password CLI Setup

#### macOS
```bash
brew install 1password-cli
```

#### Linux
```bash
# Ubuntu/Debian
curl -s https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" | sudo tee /etc/apt/sources.list.d/1password.sources.list
sudo apt update
sudo apt install 1password-cli

# Fedora/RHEL
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo dnf install 1password-cli
```

#### Windows
```powershell
choco install 1password-cli
```

### Verify Installation

```bash
op --version
```

## 1Password Vault Setup

### 1. Create a Vault

In 1Password app:
1. Click "Vaults" in sidebar
2. Click "Create Vault"
3. Name it: "Stash Deployment"
4. Set permissions as needed

### 2. Create Master Password Item

Create a new "Password" item:
- **Title**: Stash Master Password
- **Password**: Generate strong password
- **Tags**: stash, production

### 3. Create Database Credentials

Create a new "Database" item:
- **Title**: Stash Database
- **Username**: stash_user
- **Password**: Strong password
- **Host**: localhost
- **Database**: stash_db
- **Tags**: stash, database

### 4. Create API Keys

Create "Login" items for each API:
- **Scraper API Keys**
- **Reverse Proxy Credentials**
- **Backup Service Tokens**

### 5. Set Vault Access

Invite team members and set permissions:
- Can view vault items
- Can edit vault items
- Can copy passwords

## Docker Compose Integration

### Method 1: Environment File

#### 1. Create 1Password Item

In 1Password, create a "Secure Note":
- **Title**: Stash Docker Env
- **Content**: 
```
STASH_DB_USER=stash_user
STASH_DB_PASSWORD=your_password
STASH_API_KEY=your_api_key
```

#### 2. Inject into Docker Compose

```bash
# Authenticate with 1Password
eval $(op signin)

# Export environment from 1Password
export STASH_DB_PASS=$(op read op://Stash Deployment/Stash Database/password)
export STASH_API_KEY=$(op read op://Stash Deployment/Stash API Key/password)

# Start Docker Compose
docker compose up -d
```

### Method 2: 1Password Connect Server

#### 1. Deploy 1Password Connect

```bash
# Pull 1Password Connect image
docker pull 1password/connect-api:latest

# Run Connect server
docker run -d \
  --name 1password-connect \
  -p 8080:8080 \
  -v ~/1password-credentials.json:/home/opuser/.op/1password-credentials.json \
  1password/connect-api:latest
```

Get credentials from: https://start.1password.com/integrations/connect

#### 2. Update Docker Compose

Add Connect sidecar:

```yaml
version: '3.8'

services:
  connect:
    image: 1password/connect-api:latest
    container_name: 1password-connect
    ports:
      - "8080:8080"
    volumes:
      - ./1password-credentials.json:/home/opuser/.op/1password-credentials.json
    environment:
      - OP_CONNECT_TOKEN=your_connect_token
    restart: unless-stopped

  stash:
    image: stashapp/stash:latest
    container_name: stash
    ports:
      - "9999:9999"
    environment:
      - STASH_DB_USER=${STASH_DB_USER}
      - STASH_DB_PASSWORD=${STASH_DB_PASSWORD}
    volumes:
      - ./config:/root/.stash
      - ./data:/data
    depends_on:
      - connect
    restart: unless-stopped
```

#### 3. Retrieve Secrets via API

```bash
# Get secret from 1Password Connect
curl -s -H "Authorization: Bearer $OP_CONNECT_TOKEN" \
  http://localhost:8080/v1/vaults/vault_id/items/item_id \
  | jq '.details.password'
```

## Podman Quadlet Integration

### Method 1: CLI Authentication

Edit quadlet file to load secrets from 1Password:

```ini
# stash.container
[Unit]
Description=Stash - 1Password Managed
After=network-online.target

[Container]
Image=stashapp/stash:latest
ContainerName=stash
PublishPort=9999:9999

# Load environment from 1Password before container starts
ExecStartPre=bash -c 'eval $(op signin) && export STASH_DB_PASS=$(op read op://Stash Deployment/Database/password)'

Environment=STASH_DB_USER=stash_user
Environment=STASH_DB_PASSWORD=%{STASH_DB_PASS}
Environment=STASH_STASH=/data/

[Service]
Type=notify

[Install]
WantedBy=default.target
```

### Method 2: 1Password Connect Container

Create a network and use Connect:

```bash
# Create podman network
podman network create stash-network

# Start 1Password Connect
podman run -d \
  --name connect \
  --network stash-network \
  -v ~/1password-credentials.json:/home/opuser/.op/1password-credentials.json \
  1password/connect-api:latest

# Update quadlet to use Connect
# Network=stash-network
# Environment=OP_CONNECT_HOST=connect
```

## Environment Variable Management

### 1. Create Environment Template

In 1Password, create "Secure Note":

**Title**: Stash Environment

**Content**:
```bash
# Database
STASH_DB_USER=stash_user
STASH_DB_PASSWORD=<password>
STASH_DB_HOST=localhost
STASH_DB_NAME=stash

# API Keys
STASH_SCRAPER_API_KEY=<key>
STASH_BACKUP_API_TOKEN=<token>

# Security
STASH_SESSION_SECRET=<secret>
STASH_ENCRYPTION_KEY=<key>

# Configuration
STASH_PORT=9999
STASH_LOG_LEVEL=info
```

### 2. Export Script

Create `export-secrets.sh`:

```bash
#!/bin/bash
# Export secrets from 1Password for Stash

set -e

# Authenticate
eval $(op signin)

# Export environment variables
export STASH_DB_USER=$(op read op://Stash Deployment/Database/username)
export STASH_DB_PASSWORD=$(op read op://Stash Deployment/Database/password)
export STASH_SCRAPER_API_KEY=$(op read op://Stash Deployment/Scrapers/api_key)
export STASH_BACKUP_API_TOKEN=$(op read op://Stash Deployment/Backup/token)

# Start deployment
docker compose up -d
```

Make executable:
```bash
chmod +x export-secrets.sh
./export-secrets.sh
```

## Team Collaboration

### 1. Create Shared Vault

1. In 1Password, create vault: "Stash Team"
2. Invite team members
3. Set appropriate permissions

### 2. Organize Credentials

Create folders in vault:
- `Database/` - Database credentials
- `APIs/` - External API keys
- `Scrapers/` - Scraper configurations
- `Backups/` - Backup credentials
- `Reverseproxy/` - Proxy passwords

### 3. Audit Trail

1Password automatically tracks:
- Who accessed credentials
- When they accessed them
- From which device
- What was viewed/modified

View audit log in 1Password app:
Settings → Vaults → Select vault → Activity

## Security Best Practices

### 1. Master Password

- Use strong, unique master password
- Store in secure location
- Change periodically (quarterly)
- Enable two-factor authentication

### 2. CLI Access

```bash
# Sign out when done
op signout

# Use service accounts for automation
# Avoid storing credentials in files
# Use environment variables instead
```

### 3. Credential Rotation

Create calendar reminders to rotate:
- Database passwords (quarterly)
- API keys (annually or after team changes)
- Backup tokens (as needed)

### 4. Least Privilege

- Grant minimal necessary permissions
- Use separate credentials per service
- Disable access when not needed
- Audit vault access regularly

## Monitoring & Logging

### 1. Track Secret Access

In 1Password app:
1. Go to vault
2. Click on item
3. View "Activity" tab

### 2. Alert on Unauthorized Access

Set up notifications for:
- Multiple failed password attempts
- Access from unknown location
- Vault sharing changes
- Team member removal

### 3. Audit Reports

Export audit logs:
1. Settings → Reporting
2. Select date range
3. Export to CSV

## Backup & Recovery

### 1. Export Vault (Encrypted)

```bash
# Via 1Password CLI
op vault export "Stash Deployment" \
  --output-format json > stash-vault-backup.json
```

### 2. Store Backup Securely

```bash
# Encrypt backup
gpg -c stash-vault-backup.json

# Store in secure location
cp stash-vault-backup.json.gpg ~/backups/
```

### 3. Restore from Backup

```bash
# Decrypt backup
gpg stash-vault-backup.json.gpg

# Import into 1Password (via app)
```

## Troubleshooting

### 1Password CLI Issues

#### "Invalid credentials"
```bash
# Sign out and re-authenticate
op signout
eval $(op signin)
```

#### "Item not found"
```bash
# Verify vault name and item path
op item list --vault "Stash Deployment"

# Use full path
op read op://VaultName/ItemName/field
```

#### "Permission denied"
- Check vault access in 1Password app
- Ensure account has CLI access enabled
- Verify item is shared with your account

### Docker Compose Issues

#### Environment variables not set
```bash
# Verify export worked
echo $STASH_DB_PASSWORD

# Re-export if needed
eval $(op signin)
export STASH_DB_PASSWORD=$(op read op://...)
```

#### Connect server fails to start
```bash
# Check logs
docker logs 1password-connect

# Verify credentials file exists
ls -la ~/1password-credentials.json

# Restart Connect
docker restart 1password-connect
```

### Podman Quadlet Issues

#### Cannot read secrets from 1Password
```bash
# Verify 1Password CLI is installed
op --version

# Check authentication
eval $(op signin)

# Test secret read
op read op://Stash\ Deployment/Database/password
```

## Automation Examples

### Hourly Credential Sync

Create `sync-secrets.sh`:

```bash
#!/bin/bash
# Sync secrets from 1Password hourly

VAULT="Stash Deployment"
ENV_FILE=".env.1password"

# Authenticate
eval $(op signin)

# Export secrets
cat > "$ENV_FILE" << EOF
STASH_DB_PASS=$(op read op://$VAULT/Database/password)
STASH_API_KEY=$(op read op://$VAULT/APIs/key)
STASH_BACKUP_TOKEN=$(op read op://$VAULT/Backup/token)
EOF

# Set secure permissions
chmod 600 "$ENV_FILE"

# Reload environment
systemctl --user restart stash.container
```

Add to crontab:
```bash
crontab -e
# Add: 0 * * * * /path/to/sync-secrets.sh
```

### Backup Before Credential Change

```bash
#!/bin/bash
# Backup Stash data before credential rotation

BACKUP_DIR="$HOME/backups/pre-rotation"
mkdir -p "$BACKUP_DIR"

# Stop service
systemctl --user stop stash.container

# Backup database
cp ~/.stash/stash.db "$BACKUP_DIR/stash-$(date +%Y%m%d-%H%M%S).db"

# Restart
systemctl --user start stash.container

echo "Backup complete. Ready for credential rotation."
```

## Advanced: Custom Integration

### Create 1Password Item Type

Design custom "Stash Configuration" item:
- Database credentials
- API keys
- Configuration values
- Backup settings

### Use via Webhook

```bash
# 1Password webhook when credentials change
curl -X POST http://localhost:9999/api/credentials/update \
  -H "Content-Type: application/json" \
  -d '{
    "credential": "database",
    "new_value": "from-1password"
  }'
```

## Migration to 1Password

### From File-based Secrets

```bash
#!/bin/bash
# Migrate secrets from .env file to 1Password

while IFS='=' read -r key value; do
  # Create 1Password item for each secret
  echo "$value" | op item create \
    --category password \
    --title "Stash $key" \
    --vault "Stash Deployment"
done < .env.old

# Secure delete old file
shred -vfz -n 3 .env.old
```

### From Kubernetes Secrets

```bash
# Export K8s secrets
kubectl get secret stash-secrets -o json | \
  jq '.data | to_entries[]' | \
  while read -r item; do
    # Import to 1Password
    op item create ...
  done
```

## See Also

- [Docker Security](https://docs.docker.com/develop/security/)
- [1Password Developer Program](https://developer.1password.com/)
- [1Password Connect API](https://developer.1password.com/docs/connect/)
- [Podman Security](https://docs.podman.io/en/latest/markdown/podman.1.html)

## Resources

- **1Password CLI**: https://developer.1password.com/docs/cli/
- **1Password Connect**: https://developer.1password.com/docs/connect/
- **API Reference**: https://developer.1password.com/docs/connect/api/
- **Support**: https://support.1password.com/

---

**Version**: 1.0
**Last Updated**: 2026-07-10
**Tested With**: 1Password CLI 2.20+, Docker 20.10+, Podman 4.4+
