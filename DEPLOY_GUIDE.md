# Deploy Script Guide

Complete guide for using the `deploy.sh` script to push code and deploy Stash.

## Overview

The `deploy.sh` script provides a one-command solution for:
- ✅ Git status checking
- ✅ Automatic commits
- ✅ Push to remote
- ✅ Multiple deployment options
- ✅ 1Password integration
- ✅ Automatic verification

## Quick Start

### Basic Usage

```bash
# Interactive mode (choose deployment method)
./deploy.sh

# Deploy with specific method
./deploy.sh docker      # Docker Compose
./deploy.sh podman      # Podman Quadlet (user)
./deploy.sh local       # Local build

# With 1Password
./deploy.sh docker --1password
```

## Command Reference

### Deployment Methods

```bash
# Docker Compose (easiest, cross-platform)
./deploy.sh docker
# Creates ~/stash-deployment, starts container

# Podman Quadlet - User Service
./deploy.sh podman
# Sets up ~/.config/containers/systemd/, systemd service

# Podman Quadlet - System Service
./deploy.sh podman-system
# Requires sudo, system-wide deployment

# Local Build (development)
./deploy.sh local
# Builds from source, runs directly

# Git push only (no deployment)
./deploy.sh --no-deploy
```

### Advanced Options

```bash
# Use 1Password for secrets
./deploy.sh docker --1password
./deploy.sh podman --1password

# Dry run (show what would happen)
./deploy.sh --dry-run
./deploy.sh docker --dry-run

# Custom commit message
./deploy.sh docker --message "Deploy version X.Y.Z"

# Show help
./deploy.sh --help
```

## Workflow Examples

### Example 1: Quick Docker Deploy

```bash
cd /path/to/stash
./deploy.sh docker
```

**What happens:**
1. Checks git status
2. Creates commit with changes
3. Pushes to remote branch
4. Copies docker-compose.yml to ~/stash-deployment
5. Creates data directories
6. Starts Docker Compose
7. Verifies Stash is running
8. Shows access URL

**Time:** ~3 minutes

---

### Example 2: Production Podman with 1Password

```bash
cd /path/to/stash
./deploy.sh podman-system --1password
```

**What happens:**
1. Checks git status
2. Creates commit
3. Pushes to remote
4. Signs in to 1Password
5. Loads secrets from vault
6. Creates system user
7. Sets up systemd service
8. Enables on boot
9. Starts service
10. Verifies with systemctl

**Time:** ~5 minutes (including 1Password auth)

---

### Example 3: Development Cycle

```bash
# Make changes
git checkout -b feature/new-feature
# ... edit files ...

# Deploy and test locally
./deploy.sh local

# After testing, push and deploy to dev
./deploy.sh docker --message "Add new feature X"
```

---

### Example 4: Staging vs Production

```bash
# Deploy to staging (Docker)
git checkout staging
./deploy.sh docker --message "Stage release v1.0"

# After testing staging, deploy to production (Podman)
git checkout main
./deploy.sh podman-system --message "Release v1.0"
```

---

## What Each Step Does

### 1. Git Status Check

```
Checking git status
  ✓ Verifies it's a git repository
  ✓ Checks for uncommitted changes
  ✓ Prompts if changes exist
```

### 2. Git Commit

```
Preparing git commit
  ✓ Uses custom message or default
  ✓ Stages all changes
  ✓ Creates commit with message
```

### 3. Git Push

```
Pushing to git
  ✓ Identifies current branch
  ✓ Attempts push with retries
  ✓ Retries up to 4 times on failure
  ✓ Reports success/failure
```

### 4. Method Selection

```
Choose deployment method
  ✓ Shows available options
  ✓ Uses specified or interactive choice
  ✓ Checks prerequisites
```

### 5. Deployment

```
Docker Compose:
  ✓ Creates ~/stash-deployment
  ✓ Copies docker-compose.yml
  ✓ Creates data directories
  ✓ Starts containers
  ✓ Waits for startup
  ✓ Verifies connectivity

Podman Quadlet:
  ✓ Creates directories
  ✓ Copies quadlet file
  ✓ Reloads systemd
  ✓ Enables service
  ✓ Starts service
  ✓ Verifies with systemctl

Local Build:
  ✓ Installs UI dependencies
  ✓ Generates files
  ✓ Builds UI
  ✓ Builds binaries
  ✓ Runs server
```

## Error Handling

### Common Issues

#### Git Push Fails

```bash
# Script automatically retries 4 times
# If still fails:

# Check git configuration
git config --list

# Check remote
git remote -v

# Try manual push
git push -u origin $(git rev-parse --abbrev-ref HEAD)
```

#### Docker Not Available

```bash
# Script checks for Docker
# If not found:

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Or use Podman instead
./deploy.sh podman
```

#### Podman Service Won't Start

```bash
# Script verifies service started
# If fails:

# Check status manually
systemctl --user status stash.container

# View logs
journalctl --user-unit stash.container -f

# Troubleshoot
podman ps -a | grep stash
podman logs stash
```

#### 1Password Authentication Fails

```bash
# Manual auth required
eval $(op signin)

# Verify secrets exist
op vault list
op item list --vault "Stash Deployment"

# Test reading secret
op read op://Stash\ Deployment/Database/password
```

## Troubleshooting

### Check Script Version

```bash
head -3 deploy.sh
```

### Test Without Deploying

```bash
# Dry run shows what would happen
./deploy.sh docker --dry-run

# Or push only
./deploy.sh --no-deploy
```

### Manual Steps

```bash
# If script fails, manual steps:

# 1. Git operations
git add -A
git commit -m "Deploy Stash"
git push

# 2. Docker
docker compose up -d

# 3. Podman
bash podman/setup-quadlet.sh

# 4. Local
make build-release
./stash
```

### Debug Mode

Enable bash debugging:

```bash
bash -x deploy.sh docker
```

This shows each command as it runs.

## Configuration

### Custom Commit Messages

Create `.deploy-message` file:

```bash
cat > .deploy-message << 'EOF'
Deploy Stash with latest changes

Features:
- New deployment options
- Enhanced documentation
- 1Password integration
EOF

./deploy.sh docker --message "$(cat .deploy-message)"
```

### Environment Variables

Set before running:

```bash
# Skip 1Password check
export OP_SIGNIN=false

# Custom deployment path
export DEPLOY_DIR="/opt/stash"

# Custom port
export STASH_PORT=8080

./deploy.sh docker
```

### Script Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Quick deploy shortcuts
alias deploy-docker='./deploy.sh docker'
alias deploy-podman='./deploy.sh podman'
alias deploy-prod='./deploy.sh podman-system'
alias deploy-dev='./deploy.sh local'
alias deploy-1p='./deploy.sh docker --1password'
alias deploy-dry='./deploy.sh --dry-run'
```

Then use:

```bash
cd /path/to/stash
deploy-docker      # Docker
deploy-prod        # Production Podman
deploy-1p          # Docker + 1Password
```

## Monitoring After Deploy

### Docker Compose

```bash
# View logs
docker compose logs -f

# Check status
docker compose ps

# Access logs by service
docker compose logs stash -f
```

### Podman Quadlet

```bash
# View logs
journalctl --user-unit stash.container -f

# Check status
systemctl --user status stash.container

# Restart service
systemctl --user restart stash.container
```

### Access Stash

```bash
# Once running
curl http://localhost:9999

# In browser
open http://localhost:9999  # macOS
xdg-open http://localhost:9999  # Linux
start http://localhost:9999  # Windows
```

## Rollback

### If Deployment Fails

#### Docker

```bash
# Stop containers
docker compose down

# Check git log
git log --oneline -5

# Revert if needed
git revert HEAD
git push
```

#### Podman

```bash
# Stop service
systemctl --user stop stash.container

# Disable if needed
systemctl --user disable stash.container

# Check git log
git log --oneline -5

# Revert if needed
git revert HEAD
git push
```

#### Local

```bash
# Kill process
pkill -f "./stash"

# Clean build
make clean
make build-release

# Run again
./stash
```

## Advanced

### Continuous Deployment

Create cron job:

```bash
# Every hour
0 * * * * cd /path/to/stash && ./deploy.sh docker

# Every day
0 2 * * * cd /path/to/stash && ./deploy.sh podman-system
```

### Pre-Deploy Hook

Create `pre-deploy.sh`:

```bash
#!/bin/bash
# Run tests
make validate

# Check linting
make lint

# Build check
make build

echo "Pre-deploy checks passed"
```

Call from main script:

```bash
./pre-deploy.sh && ./deploy.sh docker
```

### Post-Deploy Hook

Create `post-deploy.sh`:

```bash
#!/bin/bash
# Run smoke tests
curl http://localhost:9999

# Backup database
cp ~/.stash/stash.db ~/backups/stash-$(date +%s).db

# Log deployment
echo "$(date): Deployed successfully" >> ~/deploy-log.txt
```

### Multi-Environment Deploy

```bash
#!/bin/bash
# deploy-all.sh - Deploy to multiple environments

# Dev
git checkout dev
./deploy.sh docker --message "Deploy to dev"

# Staging
git checkout staging
./deploy.sh podman --message "Deploy to staging"

# Production
git checkout main
./deploy.sh podman-system --message "Deploy to production"
```

## Best Practices

1. **Always use dry-run first**
   ```bash
   ./deploy.sh docker --dry-run
   ```

2. **Use meaningful commit messages**
   ```bash
   ./deploy.sh docker --message "feat: add new feature"
   ```

3. **Monitor after deployment**
   ```bash
   ./deploy.sh docker && docker compose logs -f
   ```

4. **Regular backups**
   ```bash
   # Before deploy
   tar -czf backup-$(date +%Y%m%d).tar.gz ~/.stash/
   ./deploy.sh docker
   ```

5. **Test in dev first**
   ```bash
   git checkout dev
   ./deploy.sh docker
   # Test thoroughly
   git checkout main
   ./deploy.sh podman-system
   ```

6. **Document changes**
   ```bash
   git log --oneline origin/main..HEAD
   # Review changes before deploy
   ```

7. **Monitor deployment**
   ```bash
   # Keep logs open
   docker compose logs -f &
   ./deploy.sh docker
   ```

## See Also

- [Quick Start](QUICK_START_DEPLOYMENT.md)
- [Installation Guide](INSTALL_AND_DEPLOY.md)
- [Deployment Comparison](DEPLOYMENT_COMPARISON.md)
- [Docker Guide](docs/bookstack/02-docker-deployment.md)
- [Podman Guide](docs/bookstack/03-podman-deployment.md)
- [1Password Integration](docs/1password/QUICK_START.md)

---

**Version**: 1.0
**Last Updated**: 2026-07-10
**Tested With**: Docker 20.10+, Podman 4.4+, Git 2.20+
