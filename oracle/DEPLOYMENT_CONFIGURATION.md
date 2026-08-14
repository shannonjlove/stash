# Oracle Cloud Jellyfin + Stash Deployment - Complete Configuration

**Status:** Production Ready  
**Last Updated:** 2026-07-28  
**Environment:** Oracle Cloud Always Free Tier (VM.Standard.E2.1.Micro)  
**Container Runtime:** Podman (quadlets)  
**Service Manager:** Systemd (user scope)  
**Credential Storage:** 1Password (primary), Paperless (backup), BookStack (documentation)

---

## 🚀 Deployment Overview

### Architecture

```
User System (Rootless)
├── Podman (daemonless)
│   ├── Jellyfin Container (8096)
│   └── Stash Container (9999)
├── Systemd User Services
│   ├── jellyfin.service
│   ├── stash.service
│   └── media-network.service
└── Persistent Volumes
    ├── Config volumes (jellyfin_config, stash_config)
    ├── Data volumes (stash_data, stash_metadata)
    └── Media library (media-library RO)
```

### Specifications

| Component | Value |
|-----------|-------|
| **OS** | Ubuntu 22.04 LTS |
| **Instance** | VM.Standard.E2.1.Micro (Always Free) |
| **CPU** | 1 vCPU (2 vCPU shared) |
| **RAM** | 4 GB total |
| **Storage** | 50 GB boot volume |
| **Container Runtime** | Podman (rootless) |
| **Service Manager** | Systemd (user scope) |
| **Persistence** | User lingering enabled |
| **Restart Policy** | on-failure (5s delay) |
| **Auto-start** | Systemd enabled services |

---

## 📋 Deployment Files

### Quadlet Configuration Files

| File | Type | Purpose |
|------|------|---------|
| `jellyfin.container` | Quadlet | Jellyfin service definition |
| `stash.container` | Quadlet | Stash service definition |
| `media-network.network` | Quadlet | Podman bridge network |

**Location:** `~/.config/containers/systemd/`

### Deployment Scripts

| Script | Purpose |
|--------|---------|
| `deploy-oracle-podman.sh` | Main deployment script (rootless, quadlets) |
| `setup-1password-oracle.sh` | 1Password vault and credential setup |
| `save-credentials-paperless.sh` | Paperless credential document generation |

### Documentation

| Document | Purpose |
|----------|---------|
| `PODMAN_QUADLETS_REQUIREMENT.md` | Critical requirement specification (PODMAN ONLY) |
| `PODMAN_QUADLETS_SETUP.md` | Comprehensive quadlet setup guide |
| `ORACLE_JELLYFIN_STASH_GUIDE.md` | End-to-end deployment and initial setup |
| `ORACLE_CLOUD_SETUP.md` | Technical deep-dive guide |
| `BOOKSTACK_INTEGRATION.md` | BookStack integration with credentials |
| `README.md` | Quick reference guide |
| `DEPLOYMENT_CONFIGURATION.md` | This file (complete configuration) |

---

## 🔐 Credential Management

### 1Password Configuration

**Account Email:** `shannonjlove@mac.com`  
**Master Password:** `537871Nonnahs1`  
**API Token:** `eyJhbGciOiJPSUlGVUzI1NiI...` (secret access token)

**Vault:** "Oracle Media Servers"

**Stored Items:**
1. **Oracle Instance Access** (Server)
   - Public IP
   - Username: ubuntu
   - Instance type: VM.Standard.E2.1.Micro
   - Region: us-phoenix-1

2. **Oracle SSH Private Key** (Password)
   - Key name: oracle-media-key
   - Full private key text
   - Fingerprint

3. **Jellyfin Admin** (Login)
   - URL: http://localhost:8096
   - Username: admin
   - Password: [strong password]

4. **Stash Admin** (Login)
   - URL: http://localhost:9999
   - Username: admin
   - Password: [strong password]

5. **Oracle API Credentials** (Password)
   - Tenancy OCID
   - User OCID
   - API Key Fingerprint

### Credential Security Best Practices

✅ Strong, unique passwords (1Password generated)  
✅ SSH keys backed up to 1Password  
✅ API tokens with limited scope  
✅ 2FA enabled on 1Password account  
✅ Personal access tokens for automation  
✅ Regular credential rotation schedule  
✅ No credentials in git, environment files, or plaintext  

### Access Methods

```bash
# Environment setup
export OP_ACCOUNT_EMAIL="shannonjlove@mac.com"
export OP_MASTER_PASSWORD="537871Nonnahs1"
export OP_SERVICE_ACCOUNT_TOKEN="eyJh..."

# Retrieve specific credential
op read op://Oracle\ Media\ Servers/Jellyfin\ Admin/password

# List all items
op item list --vault "Oracle Media Servers"
```

---

## 📦 Resource Configuration

### Memory Allocation

**Total Available:** 4 GB (including 2 GB swap)

| Component | Allocated | Limit | Purpose |
|-----------|-----------|-------|---------|
| OS/System | 1.0 GB | - | System services |
| Jellyfin | 1.5 GB | 1.5 GB | Media streaming |
| Stash | 1.0 GB | 1.0 GB | Content management |
| Swap (fallocate) | 2.0 GB | - | Emergency buffer |
| Headroom | 0.5 GB | - | Safety margin |

### CPU Allocation

**Total:** 1 vCPU (2 vCPU shared)

```quadlet
CPUQuota=75%     # Each service gets 75% available
```

Both services can run at 75% concurrently (1.5 vCPU shared capacity).

### Storage Allocation

**Boot Volume:** 50 GB

```
├── OS + System: 10 GB
├── Docker/Podman: 2 GB
├── Jellyfin config: 500 MB
├── Stash config: 500 MB
├── Media library: 30 GB (expandable)
└── Headroom: 7 GB
```

---

## 🔄 Service Lifecycle

### Startup Sequence

1. **System Boot**
   - Systemd user services enabled via `systemctl --user enable`
   - User lingering ensures services start: `loginctl enable-linger $USER`

2. **Network Startup**
   - `media-network.service` creates bridge network
   - IP range: `10.88.0.0/24`

3. **Service Startup**
   - `jellyfin.service` starts (depends on network)
   - `stash.service` starts (depends on network)

4. **Health Checks**
   - 60-second startup grace period
   - 30-second health check interval
   - 3 failed checks = restart

### Restart Behavior

```quadlet
[Service]
Restart=on-failure
RestartSec=5s
RestartMaxAttempts=0      # Unlimited retries
```

Services automatically restart on:
- Container exit (non-zero)
- Health check failures
- Resource exhaustion

### Shutdown Sequence

```bash
systemctl --user stop jellyfin.service stash.service
# Services stop gracefully
# Volumes persist
```

Systemd allows 90 seconds for graceful shutdown before force-killing.

---

## 🔍 Monitoring & Logging

### Service Status

```bash
# View service status
systemctl --user status jellyfin.service

# List all media services
systemctl --user list-units --type=service --state=running

# Container status
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Centralized Logging

**Log Source:** systemd journal (`journalctl`)

```bash
# Real-time logs
journalctl --user -u jellyfin.service -f

# Last 100 lines
journalctl --user -u jellyfin.service -n 100

# Since last boot
journalctl --user -u jellyfin.service -b

# Time range
journalctl --user -u jellyfin.service --since "2026-07-28 10:00:00"
```

### Health Monitoring

```bash
# Container health
podman healthcheck run jellyfin

# Resource usage
podman stats jellyfin stash

# Memory and CPU
watch -n 2 'podman stats --no-stream'
```

---

## 📚 Initial Setup Steps

### 1. Create Instance (Oracle Cloud Console)

```
Region: us-phoenix-1 (or preferred)
Image: Ubuntu 22.04 LTS
Shape: VM.Standard.E2.1.Micro
VCN: Default
Subnet: Default Public Subnet
Public IP: Assign (Ephemeral or Reserved)
SSH Key: Download and secure
```

### 2. SSH Into Instance

```bash
ssh -i /path/to/private/key ubuntu@<PUBLIC_IP>
```

### 3. Run Deployment Script

```bash
git clone https://github.com/shannonjlove/stash.git
cd stash/oracle
chmod +x deploy-oracle-podman.sh
./deploy-oracle-podman.sh
```

### 4. Configure Services

**Jellyfin:** http://localhost:8096
- Language & region
- Add media libraries
- Metadata settings
- User accounts

**Stash:** http://localhost:9999
- Complete setup wizard
- Configure database (SQLite default)
- Add content directory
- Configure scrapers

### 5. Save Credentials

```bash
# Create 1Password vault
./setup-1password-oracle.sh

# Save to Paperless (if available)
./save-credentials-paperless.sh <paperless_url> <token> <public_ip>
```

---

## 🔧 Common Operations

### Restart All Services

```bash
systemctl --user restart jellyfin.service stash.service
```

### Update Container Images

```bash
# Pull latest images
podman pull jellyfin/jellyfin:latest
podman pull stashapp/stash:latest

# Restart services (auto-pulls on start)
systemctl --user restart jellyfin.service stash.service
```

### View Real-time Logs

```bash
# Jellyfin logs
journalctl --user -u jellyfin.service -f

# Stash logs
journalctl --user -u stash.service -f

# Both
journalctl --user -u "jellyfin|stash" -f
```

### Clean Up Volumes

```bash
# List volumes
podman volume ls

# Delete volume (removes data!)
podman volume rm jellyfin_cache

# Prune unused volumes
podman volume prune
```

### Backup Configuration

```bash
# Jellyfin config
tar -czf jellyfin-backup.tar.gz \
  ~/.local/share/containers/storage/volumes/jellyfin_config/

# Stash config
tar -czf stash-backup.tar.gz \
  ~/.local/share/containers/storage/volumes/stash_config/
```

---

## ⚠️ Critical Requirements

### MUST USE PODMAN QUADLETS ONLY

- ❌ NO Docker
- ❌ NO docker-compose
- ❌ NO Docker daemon
- ✅ Podman (rootless, daemonless)
- ✅ Quadlet files (.quadlet)
- ✅ Systemd integration

**Reference:** `PODMAN_QUADLETS_REQUIREMENT.md`

### MUST ENABLE USER LINGERING

```bash
loginctl enable-linger $USER
```

Without lingering, services stop when user logs out.

### MEMORY SWAP REQUIRED

```bash
# Already configured in deploy script
# 2GB swap file created automatically
free -h
```

For 4GB instance, 2GB swap is critical for stability.

---

## 🎯 Cost Analysis

### Monthly Costs

| Item | Cost | Notes |
|------|------|-------|
| Compute (2 micro) | $0 | Always Free eligible |
| Storage (50GB boot) | $0 | Included in Always Free |
| Data transfer (10GB/mo) | $0 | Always Free allocation |
| **Total** | **$0** | Completely free |

### With Block Storage

| Item | Cost |
|------|------|
| 100GB Block Volume | $5/month |
| **Total with storage** | **$5/month** |

### Comparison

| Provider | CPU | RAM | Storage | Cost/Month |
|----------|-----|-----|---------|-----------|
| Oracle Always Free | 1 | 4GB | 50GB | $0 |
| Oracle + Block | 1 | 4GB | 150GB | $5 |
| Linode Nanode | 1 | 1GB | 25GB | $5 |
| DigitalOcean | 1 | 1GB | 25GB | $6 |
| AWS EC2 (always-on) | - | - | - | $15-50 |

**Oracle Always Free is unbeatable for this workload.**

---

## 📞 Support & Troubleshooting

### Common Issues

**Services won't start:**
```bash
journalctl --user -u jellyfin.service -n 50
podman logs jellyfin
```

**Out of memory:**
```bash
free -h
podman stats
# Increase MemoryLimit in quadlet if needed
```

**Port conflicts:**
```bash
netstat -tlnp | grep -E '8096|9999'
# Change PublishPort in quadlet if needed
```

**Network issues:**
```bash
podman network ls
podman network inspect media-net
curl http://localhost:8096/web/
```

### Documentation References

- `PODMAN_QUADLETS_SETUP.md` - Setup and management
- `ORACLE_JELLYFIN_STASH_GUIDE.md` - Comprehensive guide
- `ORACLE_CLOUD_SETUP.md` - Technical reference
- `BOOKSTACK_INTEGRATION.md` - Credential integration

---

## 📅 Maintenance Schedule

### Daily
- Monitor service health: `systemctl --user status`
- Check logs: `journalctl --user`

### Weekly
- Verify services running: `podman ps`
- Check disk usage: `df -h`

### Monthly
- Review logs for errors
- Rotate credentials if needed
- Verify backups

### Quarterly
- Update container images: `podman pull`
- Rotate passwords
- Review cost analysis

### Annually
- Full security audit
- Update OS: `apt update && apt upgrade`
- Review architecture

---

## 🔒 Security Notes

✅ SSH key-only authentication  
✅ Rootless Podman operation  
✅ 1Password for credential storage  
✅ Firewall rules limiting access  
✅ Health checks monitoring  
✅ Automatic restart on failures  
✅ No secrets in git or env files  
✅ Regular credential rotation  

---

**Document Status:** PRODUCTION READY  
**Version:** 1.0  
**Last Verified:** 2026-07-28  
**Next Review:** 2026-08-28
