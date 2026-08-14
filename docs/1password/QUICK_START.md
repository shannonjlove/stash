# 1Password Integration - Quick Start

Get 1Password working with Stash in 5 minutes.

## Prerequisites

- 1Password account (Business or Team)
- 1Password CLI installed
- Docker or Podman

## 1-Minute Setup

### Step 1: Create 1Password Vault

In 1Password app:
1. Click "Vaults"
2. Click "Create Vault"
3. Name it: "Stash Deployment"
4. Save

### Step 2: Add Credentials

Create these items in the vault:

**Item 1: Stash Database**
- Type: Database
- Username: `stash_user`
- Password: (generate strong password)

**Item 2: Stash Scrapers**
- Type: Login
- Username: scrapers_api
- Password: (your API key)

### Step 3: Authenticate CLI

```bash
# Sign in to 1Password
op signin

# Test it works
op vault list
```

### Step 4: Export Secrets (Docker)

```bash
# Export from 1Password
eval $(op signin)
export STASH_DB_USER=$(op read op://Stash\ Deployment/Stash\ Database/username)
export STASH_DB_PASSWORD=$(op read op://Stash\ Deployment/Stash\ Database/password)

# Start Stash
docker compose up -d
```

### Step 5: Verify

```bash
# Check Stash is running
curl http://localhost:9999

# View logs
docker compose logs stash
```

---

## Docker Compose Quick Start

### 1. Copy Configuration

```bash
cp docs/1password/docker-compose-1password.yml docker-compose.yml
```

### 2. Create .env

```bash
cat > .env << EOF
STASH_PORT=9999
STASH_DB_USER=stash_user
STASH_DB_PASSWORD=
STASH_SCRAPER_API_KEY=
EOF
```

### 3. Load Secrets

```bash
# Authenticate
eval $(op signin)

# Export all secrets
export STASH_DB_USER=$(op read op://Stash\ Deployment/Stash\ Database/username)
export STASH_DB_PASSWORD=$(op read op://Stash\ Deployment/Stash\ Database/password)
export STASH_SCRAPER_API_KEY=$(op read op://Stash\ Deployment/Stash\ Scrapers/password)
```

### 4. Start

```bash
docker compose up -d
```

---

## Podman Quadlet Quick Start

### 1. Create Quadlet

```bash
cp podman/quadlet/stash-1password.container ~/.config/containers/systemd/
```

### 2. Create Script

Create `~/start-stash-1password.sh`:

```bash
#!/bin/bash
eval $(op signin)
export STASH_DB_USER=$(op read op://Stash\ Deployment/Stash\ Database/username)
export STASH_DB_PASSWORD=$(op read op://Stash\ Deployment/Stash\ Database/password)
systemctl --user start stash-1password.container
```

Make executable:
```bash
chmod +x ~/start-stash-1password.sh
```

### 3. Start

```bash
# Reload
systemctl --user daemon-reload

# Start
./start-stash-1password.sh

# Verify
systemctl --user status stash-1password.container
```

---

## Common 1Password Commands

### Read Secret

```bash
# General format
op read op://VaultName/ItemName/field

# Examples
op read op://Stash\ Deployment/Stash\ Database/username
op read op://Stash\ Deployment/Stash\ Database/password
```

### List Vaults

```bash
op vault list
```

### List Items in Vault

```bash
op item list --vault "Stash Deployment"
```

### View Item Details

```bash
op item get "Stash Database" --vault "Stash Deployment"
```

### Create Item

```bash
op item create --category password \
  --title "Stash API Key" \
  --vault "Stash Deployment" \
  password=your_key_here
```

### Sign Out

```bash
op signout
```

---

## Troubleshooting

### "Not Authenticated"

```bash
eval $(op signin)
```

### "Item Not Found"

```bash
# Check vault name
op vault list

# List items in vault
op item list --vault "Stash Deployment"

# Verify item path
op item get "Stash Database"
```

### "Permission Denied"

- Check vault access in 1Password app
- Ensure your account has vault access
- Verify 1Password CLI has permissions

### Environment Variables Not Set

```bash
# Test export
echo $STASH_DB_PASSWORD

# Re-export if empty
export STASH_DB_PASSWORD=$(op read op://Stash\ Deployment/Stash\ Database/password)
echo $STASH_DB_PASSWORD
```

---

## Next Steps

1. ✅ 1Password integration working
2. 📝 Add more secrets as needed
3. 🔄 Set up credential rotation
4. 👥 Share vault with team
5. 📊 Monitor vault audit logs

---

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# 1Password helpers
alias op-signin='eval $(op signin)'
alias op-stash-pass='op read op://Stash\ Deployment/Stash\ Database/password'
alias op-stash-user='op read op://Stash\ Deployment/Stash\ Database/username'

# Start Stash with 1Password
alias start-stash='op-signin && \
  export STASH_DB_USER=$(op-stash-user) && \
  export STASH_DB_PASSWORD=$(op-stash-pass) && \
  docker compose up -d'
```

Then use:
```bash
start-stash
```

---

## See Also

- [Full Setup Guide](1PASSWORD_SETUP.md)
- [1Password CLI Docs](https://developer.1password.com/docs/cli/)
- [1Password Connect API](https://developer.1password.com/docs/connect/)

## Resources

- **1Password**: https://1password.com
- **1Password CLI**: https://developer.1password.com/docs/cli/
- **Developer Program**: https://developer.1password.com/
- **Support**: https://support.1password.com/

---

**Time to complete**: ~5 minutes
**Difficulty**: ⭐⭐ (Easy)
**Requirements**: 1Password account, CLI
