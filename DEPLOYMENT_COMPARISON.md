# Stash Deployment Options Comparison

This guide helps you choose the right deployment method for your Stash installation.

## Deployment Methods

| Method | Complexity | Best For | Platform Support |
|--------|-----------|----------|------------------|
| **Docker Compose** | Low | Development, testing, Docker users | Linux, macOS, Windows |
| **Podman Quadlet** | Low | Production, systemd users, rootless | Linux (systemd-based) |
| **Local Build** | Medium | Development, customization | Linux, macOS, Windows |
| **Kubernetes** | High | Large deployments, clustering | Enterprise |

## Docker Compose vs Podman Quadlet

### Docker Compose

**Advantages:**
- ✅ Most portable (Windows, macOS, Linux)
- ✅ Easy multi-container setup
- ✅ Familiar to most users
- ✅ Good for development
- ✅ Live updates via `docker compose up`

**Disadvantages:**
- ❌ Requires Docker daemon running
- ❌ Manual startup management
- ❌ Container logs separate from systemd
- ❌ Less integrated with host system
- ❌ Requires docker-compose binary

**Best for:**
- Cross-platform deployments
- Development environments
- Users comfortable with Docker
- Multi-container setups

**Setup time:** ~3 minutes

**Resource usage:** Docker daemon overhead (~100-200MB)

```bash
cd ~/stash-deployment
docker compose up -d
```

### Podman Quadlet

**Advantages:**
- ✅ Native systemd integration
- ✅ Daemonless architecture
- ✅ Better security (rootless mode)
- ✅ Lower overhead than Docker
- ✅ Auto-restart built-in
- ✅ Journal logging integration
- ✅ Service management with systemctl

**Disadvantages:**
- ❌ Linux/systemd only
- ❌ Steeper learning curve for Docker users
- ❌ Requires Podman 4.4+
- ❌ Less mature than Docker

**Best for:**
- Production Linux deployments
- Systemd-based systems
- Users wanting systemd integration
- Resource-constrained systems

**Setup time:** ~2 minutes

**Resource usage:** Minimal (~10-20MB overhead)

```bash
bash podman/setup-quadlet.sh
```

## Feature Comparison

### Startup & Auto-start

| Feature | Docker Compose | Podman Quadlet |
|---------|---|---|
| Manual startup | ✅ `docker compose up` | ✅ `systemctl start` |
| Auto-start on boot | ✅ Via systemd-docker | ✅ `systemctl enable` |
| Restart policy | ✅ restart: always | ✅ RestartPolicy=on-failure |
| Health checks | ✅ Via compose | ✅ Via systemd |

### Logging & Monitoring

| Feature | Docker Compose | Podman Quadlet |
|---------|---|---|
| View logs | ✅ `docker compose logs` | ✅ `journalctl` |
| Real-time logs | ✅ `docker compose logs -f` | ✅ `journalctl -f` |
| Log rotation | ✅ Via Docker | ✅ Via systemd |
| Log search | ⚠️ Limited | ✅ Full journalctl |
| Integration | ⚠️ Separate | ✅ Integrated |

### Management

| Feature | Docker Compose | Podman Quadlet |
|---------|---|---|
| Start/stop | ✅ `docker compose` | ✅ `systemctl` |
| Status check | ✅ `docker compose ps` | ✅ `systemctl status` |
| Container exec | ✅ `docker compose exec` | ✅ `podman exec` |
| View config | ✅ `docker compose config` | ✅ Quadlet file |
| Update image | ✅ `docker compose pull` | ✅ `podman pull` |

### Security

| Feature | Docker Compose | Podman Quadlet |
|---------|---|---|
| Rootless mode | ⚠️ Limited | ✅ Full support |
| User isolation | ⚠️ Requires setup | ✅ Built-in |
| Network isolation | ✅ Via Docker | ✅ Via Podman |
| Resource limits | ✅ Via compose | ✅ Via systemd |
| Secrets management | ✅ Via files | ✅ Via systemd |

### Performance

| Aspect | Docker Compose | Podman Quadlet |
|--------|---|---|
| Startup time | ~2-3 seconds | ~1-2 seconds |
| Memory overhead | ~150MB (daemon) | ~20MB |
| Disk overhead | ~1GB (daemon) | Minimal |
| CPU overhead | Daemon running | Minimal |
| Network efficiency | Standard | Optimized |

## Platform Support

### Docker Compose
- ✅ Linux (all distributions)
- ✅ macOS (Intel and Apple Silicon)
- ✅ Windows (with Docker Desktop)
- ✅ Cloud (AWS, Azure, GCP)

### Podman Quadlet
- ✅ Linux (systemd-based)
  - ✅ Ubuntu 20.04+
  - ✅ Debian 11+
  - ✅ RHEL/CentOS 8+
  - ✅ Fedora 35+
  - ✅ Arch Linux
- ❌ macOS (native podman requires VM)
- ❌ Windows (native podman requires WSL2)
- ⚠️ Cloud (requires systemd)

## Installation Requirements

### Docker Compose
```bash
# Ubuntu/Debian
sudo apt install docker.io docker-compose

# macOS
brew install docker docker-compose

# Or use Docker Desktop
```

### Podman Quadlet
```bash
# Ubuntu/Debian
sudo apt install podman

# Fedora
sudo dnf install podman

# Arch Linux
sudo pacman -S podman
```

## Migration Guide

### From Docker Compose to Podman Quadlet

```bash
# Stop Docker Compose
docker compose down

# Create directories
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}

# Copy data (if using volumes)
docker cp stash:/root/.stash/config/. ~/.stash/config/

# Setup Podman quadlet
bash podman/setup-quadlet.sh

# Verify
systemctl --user status stash.container
```

### From Podman Quadlet to Docker Compose

```bash
# Stop quadlet
systemctl --user stop stash.container

# Create Docker deployment directory
mkdir -p ~/stash-deployment
cd ~/stash-deployment
cp docker/production/docker-compose.yml .
mkdir -p {config,data,metadata,cache,blobs,generated}

# Copy data
cp -r ~/.stash/* ./

# Start with Docker Compose
docker compose up -d
```

## Recommendation Decision Tree

```
Do you have Docker installed?
├─ Yes → Docker Compose (familiar, portable)
└─ No  → Have Podman?
         ├─ Yes, on Linux with systemd → Podman Quadlet (better integration)
         └─ No → Local build or install Docker/Podman

Need multi-container setup?
├─ Yes → Docker Compose (better support)
└─ No  → Podman Quadlet (simpler, more efficient)

Running on production server?
├─ Yes, Linux with systemd → Podman Quadlet (better monitoring)
└─ Yes, other OS → Docker Compose
└─ No, development → Docker Compose (easier iteration)

Want minimal overhead?
├─ Yes → Podman Quadlet (~20MB overhead)
└─ Acceptable → Docker Compose (~150MB overhead)

Prefer systemd integration?
├─ Yes → Podman Quadlet
└─ No → Docker Compose
```

## Quick Start

### Docker Compose (3 minutes)
```bash
cd ~/stash-deployment
docker compose up -d
# Access at http://localhost:9999
```

### Podman Quadlet (2 minutes)
```bash
bash podman/setup-quadlet.sh
# Access at http://localhost:9999
```

### Local Build (15 minutes)
```bash
cd /path/to/stash
make pre-ui
make generate
make ui
make build-release
./stash
# Access at http://localhost:9999
```

## Documentation Links

- **Docker Compose Setup**: [QUICK_START_DEPLOYMENT.md](QUICK_START_DEPLOYMENT.md)
- **Docker Full Guide**: [INSTALL_AND_DEPLOY.md](INSTALL_AND_DEPLOY.md)
- **Podman Quadlet Setup**: [podman/QUADLET_QUICK_START.md](podman/QUADLET_QUICK_START.md)
- **Podman Full Guide**: [podman/QUADLET_SETUP.md](podman/QUADLET_SETUP.md)
- **Local Build**: [INSTALL_AND_DEPLOY.md#local-build](INSTALL_AND_DEPLOY.md)

## Performance Comparison

### Startup Time
```
Podman Quadlet:  ~1-2 seconds (fastest)
Docker Compose:  ~2-3 seconds
Local Build:     ~3-5 seconds
```

### Memory Usage
```
Podman Quadlet:  30-50MB
Docker Compose:  180-250MB
Local Build:     100-150MB
```

### CPU Usage (idle)
```
Podman Quadlet:  <1%
Docker Compose:  ~2-3%
Local Build:     <1%
```

## Summary

**Choose Docker Compose if:**
- You use macOS or Windows
- You want cross-platform compatibility
- You're already familiar with Docker
- You need multi-container setups
- You want the easiest setup

**Choose Podman Quadlet if:**
- You're on Linux with systemd
- You want systemd integration
- You prefer minimal overhead
- You want better security (rootless)
- You value native Linux integration

**Choose Local Build if:**
- You want to contribute to development
- You need custom modifications
- You want maximum control
- You don't want containerization overhead

---

**Version**: 1.0
**Last Updated**: 2026-07-10
