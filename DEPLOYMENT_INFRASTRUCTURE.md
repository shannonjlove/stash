# Stash Deployment Infrastructure

Complete infrastructure for installing, deploying, and managing Stash across multiple environments with integrated knowledge management and credential security.

## Overview

This deployment infrastructure provides:
- **Multi-platform support**: Docker, Podman, Local builds
- **Unified automation**: Single script for git operations and deployment
- **Secure credentials**: 1Password integration for secrets management
- **Knowledge management**: BookStack and Paperless documentation integration
- **Template system**: Customizable configurations for different scenarios
- **Comprehensive documentation**: Guides for every deployment method

## Quick Start

### Deploy Stash (3 minutes)

```bash
# Using Docker (easiest)
./deploy.sh docker

# Using Podman
./deploy.sh podman

# Interactive mode (choose method)
./deploy.sh
```

### Import Documentation

```bash
# To BookStack
./scripts/import-all.sh --bookstack https://bookstack.example.com token

# To Paperless
./scripts/import-all.sh --paperless https://paperless.example.com token

# To both
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=token1
export PAPERLESS_URL=https://paperless.example.com
export PAPERLESS_TOKEN=token2
./scripts/import-all.sh --both
```

## Directory Structure

```
stash/
├── deploy.sh                          # Main deployment script
├── DEPLOY_GUIDE.md                    # Deploy script documentation
├── DEPLOYMENT_COMPARISON.md           # Compare deployment methods
├── DEPLOYMENT_INFRASTRUCTURE.md       # This file
├── INSTALL_AND_DEPLOY.md              # Complete installation guide
├── QUICK_START_DEPLOYMENT.md          # 5-minute quick start
│
├── docker/
│   └── production/
│       ├── deploy.sh                  # Docker setup helper
│       └── .env.example               # Environment variables
│
├── podman/
│   ├── quadlet/
│   │   ├── stash.container            # User service (auto-generated)
│   │   ├── stash-system.container     # System service (auto-generated)
│   │   ├── stash-1password.container  # 1Password version (auto-generated)
│   │   ├── stash.container.template   # Template source
│   │   └── stash.config.template      # Configuration template
│   ├── QUADLET_SETUP.md               # Comprehensive quadlet guide
│   ├── QUADLET_QUICK_START.md         # 5-minute Podman setup
│   ├── TEMPLATE_USAGE.md              # Template system documentation
│   ├── setup-quadlet.sh               # Setup automation script
│   └── generate-quadlet.py            # Template generator
│
├── docs/
│   ├── bookstack/
│   │   ├── BOOKSTACK_IMPORT.md        # Import instructions
│   │   ├── 01-quick-start.md          # Quick start guide
│   │   ├── 02-docker-deployment.md    # Docker guide
│   │   ├── 03-podman-deployment.md    # Podman guide
│   │   └── 04-deployment-comparison.md # Comparison
│   │
│   └── 1password/
│       ├── 1PASSWORD_SETUP.md         # Full setup guide
│       ├── QUICK_START.md             # Quick start
│       └── docker-compose-1password.yml # Example compose
│
└── scripts/
    ├── import-all.sh                  # Unified import orchestrator
    ├── import-bookstack.sh            # BookStack REST API import
    ├── import-paperless.sh            # Paperless document import
    └── README.md                      # Scripts documentation
```

## Key Features

### 1. Unified Deploy Script (`deploy.sh`)

Single command to push code and deploy Stash.

**Features:**
- Git status checking and validation
- Automatic commit creation with custom messages
- Push to remote with exponential backoff retry (2s, 4s, 8s, 16s)
- Support for 4 deployment methods
- 1Password credential integration
- Dry-run mode for testing
- Detailed error handling

**Deployment Methods:**
1. **Docker Compose** - Easiest, cross-platform, ~3 minutes
2. **Podman (User)** - Linux native, user-level service, ~2 minutes
3. **Podman (System)** - Production, system-wide, ~5 minutes
4. **Local Build** - Development, from source, ~15 minutes

**Usage:**
```bash
./deploy.sh docker              # Docker deployment
./deploy.sh podman              # Podman user service
./deploy.sh podman-system       # Podman system service
./deploy.sh local               # Local build
./deploy.sh --dry-run           # Test without changes
./deploy.sh docker --1password  # With 1Password integration
```

### 2. Podman Quadlet Template System

Customize Podman deployments for different scenarios.

**Templates:**
- `stash.container.template` - Main service template
- `stash.config.template` - Configuration variables

**Generator Script** (`generate-quadlet.py`):
- Load templates
- Validate configuration
- Generate customized quadlet files
- Preview before writing

**Use Cases:**
- Multiple Stash instances
- Dev vs. Production configurations
- Custom resource constraints
- Different storage paths
- Team-based deployments

**Usage:**
```bash
python3 podman/generate-quadlet.py -c custom.config -o stash-custom.container
```

### 3. Secure Credential Management (1Password)

Integrated 1Password support for secure credential storage and injection.

**Setup:**
1. Create 1Password vault "Stash Deployment"
2. Add credential items (database user, password, API keys)
3. Use in deployment with `--1password` flag

**Integration Points:**
- Docker Compose: Environment variable injection
- Podman: Environment variable injection via wrapper script
- Deploy Script: Automatic secret loading

**Documentation:**
- `docs/1password/1PASSWORD_SETUP.md` - Complete setup
- `docs/1password/QUICK_START.md` - 5-minute quickstart
- `podman/quadlet/stash-1password.container` - Example quadlet

**Usage:**
```bash
./deploy.sh docker --1password
./deploy.sh podman-system --1password
```

### 4. Comprehensive Documentation

Multi-format documentation for all skill levels.

**Quick Starts** (5-10 minutes):
- `QUICK_START_DEPLOYMENT.md` - All methods overview
- `docs/1password/QUICK_START.md` - 1Password setup
- `podman/QUADLET_QUICK_START.md` - Podman setup

**Complete Guides** (30+ pages):
- `INSTALL_AND_DEPLOY.md` - Platform-specific installation
- `DEPLOY_GUIDE.md` - Deploy script reference
- `podman/QUADLET_SETUP.md` - Advanced Podman configuration
- `docs/1password/1PASSWORD_SETUP.md` - Full 1Password integration

**Comparison & Reference:**
- `DEPLOYMENT_COMPARISON.md` - Feature comparison
- `podman/TEMPLATE_USAGE.md` - Template system reference
- `docs/bookstack/04-deployment-comparison.md` - Method comparison

### 5. Knowledge Management Integration

Automatic documentation import to BookStack and Paperless.

**BookStack Import** (`scripts/import-bookstack.sh`):
- Creates hierarchical structure (Shelf → Books → Chapters → Pages)
- Automatic content conversion
- Supports REST API for programmatic access

**Paperless Import** (`scripts/import-paperless.sh`):
- Converts markdown to PDF
- Automatic tagging for organization
- Full-text searchable documents

**Unified Tool** (`scripts/import-all.sh`):
- Single command for both systems
- Environment variable support
- Progress reporting

**Usage:**
```bash
# Setup environment
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=token123
export PAPERLESS_URL=https://paperless.example.com
export PAPERLESS_TOKEN=token456

# Import to both
./scripts/import-all.sh --both

# Or individually
./scripts/import-bookstack.sh $BOOKSTACK_URL $BOOKSTACK_TOKEN
./scripts/import-paperless.sh $PAPERLESS_URL $PAPERLESS_TOKEN
```

## Deployment Comparison

| Feature | Docker | Podman (User) | Podman (System) | Local |
|---------|--------|---------------|-----------------|-------|
| Setup Time | 3 min | 2 min | 5 min | 15 min |
| Cross-Platform | ✓ | ✗ (Linux) | ✗ (Linux) | ✓ |
| Rootless | ✓ | ✓ | ✗ | N/A |
| Auto-Restart | ✓ | ✓ | ✓ | ✗ |
| Production Ready | ✓ | ✓ | ✓✓ | ✗ |
| Development | ✓ | ✓ | ✓ | ✓✓ |
| 1Password Support | ✓ | ✓ | ✓ | ✗ |

## Common Workflows

### Development Setup

```bash
# Clone and setup
git clone https://github.com/stashapp/stash.git
cd stash

# Deploy locally for testing
./deploy.sh local

# Or with Docker
./deploy.sh docker
```

### Production Deployment

```bash
# Set 1Password credentials
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=token

# Deploy to production with 1Password
./deploy.sh podman-system --1password

# Verify
systemctl status stash.container
journalctl --user-unit stash.container -f

# Access
curl http://localhost:9999
```

### Team Deployment with Custom Config

```bash
# Create custom configuration
cp podman/quadlet/stash.config.template team.config
# Edit team.config with custom values

# Generate custom quadlet
python3 podman/generate-quadlet.py -c team.config -o stash-team.container

# Preview
python3 podman/generate-quadlet.py -c team.config -p

# Deploy
sudo cp stash-team.container /etc/containers/systemd/
systemctl daemon-reload
systemctl start stash-team.service
```

### Documentation Integration

```bash
# After deployment, import docs to knowledge base
cd scripts

# To BookStack
./import-bookstack.sh https://bookstack.example.com $TOKEN

# To Paperless
./import-paperless.sh https://paperless.example.com $TOKEN

# To both
./import-all.sh --both https://bookstack.example.com $BS_TOKEN \
                        https://paperless.example.com $PL_TOKEN
```

## Requirements

### Minimum
- Bash 4.0+
- Git 2.20+
- curl

### For Docker Deployment
- Docker 20.10+
- Docker Compose

### For Podman Deployment
- Podman 4.4+
- systemd

### For Local Build
- Go 1.21+
- Node.js 18+
- SQLite3

### For Documentation Import
- curl (required)
- jq (for BookStack)
- pandoc (for Paperless PDF conversion)

**Installation:**
```bash
# Ubuntu/Debian
sudo apt-get install -y curl jq pandoc pandoc-citeproc

# With optional PDF quality improvement
sudo apt-get install -y wkhtmltopdf
```

## Security Considerations

1. **Credential Management**
   - Use 1Password for all sensitive data
   - Never commit secrets to git
   - Rotate credentials regularly

2. **Network Security**
   - Stash runs on localhost:9999 by default
   - Use reverse proxy (nginx, traefik) for public access
   - Enable SSL/TLS for external access
   - Use strong authentication

3. **File Permissions**
   - Data directories owned by stash user (Podman system)
   - Restrict access to config files
   - Regular backups of data

4. **Updates**
   - Keep Docker/Podman images updated
   - Regular security patches
   - Monitor GitHub for security advisories

## Troubleshooting

### Docker Issues

**Docker daemon not running:**
```bash
# Start Docker
sudo systemctl start docker

# Check status
sudo systemctl status docker
```

**Permission denied:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Podman Issues

**Service won't start:**
```bash
# Check status
systemctl --user status stash.container

# View logs
journalctl --user-unit stash.container -f

# Enable linger (user services persist after logout)
loginctl enable-linger $USER
```

**Database connection errors:**
```bash
# Verify environment variables are set
env | grep STASH_DB

# Check 1Password authentication
eval $(op signin)
op vault list
```

### Network Issues

**Cannot access http://localhost:9999:**
```bash
# Check if service is running
docker ps | grep stash
# or
podman ps | grep stash

# Check port
netstat -tuln | grep 9999

# Check logs
docker compose logs stash
# or
journalctl --user-unit stash.container -f
```

## Advanced Configuration

### Custom Port

```bash
# Docker
STASH_PORT=8080 ./deploy.sh docker

# Podman
export STASH_PORT=8080
python3 podman/generate-quadlet.py -c podman/quadlet/stash.config.template
```

### Custom Storage

```bash
# Create template with custom paths
cp podman/quadlet/stash.config.template custom.config
# Edit custom.config to set:
# STASH_DATA_DIR=/custom/path
# STASH_CACHE_DIR=/custom/cache
# etc.

# Generate with custom config
python3 podman/generate-quadlet.py -c custom.config -o stash-custom.container
```

### Multiple Instances

```bash
# Create config for instance 1
cp podman/quadlet/stash.config.template stash1.config
# Edit stash1.config with custom name, port, etc.

# Create config for instance 2
cp podman/quadlet/stash.config.template stash2.config
# Edit stash2.config with different values

# Generate quadlets
python3 podman/generate-quadlet.py -c stash1.config -o stash-1.container
python3 podman/generate-quadlet.py -c stash2.config -o stash-2.container

# Deploy both
cp stash-1.container stash-2.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start stash-1.service stash-2.service
```

## Performance Tuning

### Resource Limits

Edit container configuration:
```
Memory=2g          # Limit to 2GB
MemorySwap=4g      # Allow 4GB total with swap
CPUQuota=80%       # Limit to 80% CPU
```

### Database Optimization

Use PostgreSQL instead of SQLite for production:
```bash
export STASH_DB_HOST=postgres.example.com
export STASH_DB_USER=stash
export STASH_DB_PASSWORD=...
export STASH_DB_NAME=stash

./deploy.sh docker
```

## Monitoring and Maintenance

### Check Status

```bash
# Docker
docker compose ps
docker compose logs stash

# Podman
systemctl --user status stash.container
journalctl --user-unit stash.container -f
```

### Backup Data

```bash
# Backup directories
tar -czf stash-backup-$(date +%Y%m%d).tar.gz ~/.stash/

# Or for Docker
docker compose exec stash tar -czf - /data > stash-backup-$(date +%Y%m%d).tar.gz
```

### Update Stash

```bash
# Pull latest code
git pull origin main

# Redeploy
./deploy.sh docker

# Or just update image
docker compose pull
docker compose up -d
```

## Related Documentation

- [Installation and Deployment](INSTALL_AND_DEPLOY.md)
- [Quick Start](QUICK_START_DEPLOYMENT.md)
- [Deploy Script Guide](DEPLOY_GUIDE.md)
- [Deployment Comparison](DEPLOYMENT_COMPARISON.md)
- [1Password Integration](docs/1password/1PASSWORD_SETUP.md)
- [Podman Quadlet Setup](podman/QUADLET_SETUP.md)
- [Template System](podman/TEMPLATE_USAGE.md)
- [Import Scripts](scripts/README.md)

## Summary

This infrastructure provides:

✓ **Multi-environment support** - Docker, Podman, Local  
✓ **Unified automation** - Single script for deploy  
✓ **Secure credentials** - 1Password integration  
✓ **Knowledge management** - BookStack & Paperless  
✓ **Customizable deployment** - Template system  
✓ **Comprehensive docs** - Guides for all skill levels  
✓ **Production ready** - Error handling, monitoring, backups  
✓ **Community focused** - Well documented, easy to extend  

Everything needed to install, deploy, and manage Stash at scale.

---

**Version**: 1.0  
**Last Updated**: 2026-07-25  
**Branch**: `claude/stash-install-deploy-ni5bdd`
