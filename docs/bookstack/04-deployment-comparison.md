# Deployment Methods Comparison

Choose the right deployment method for your needs.

## Overview

| Method | Complexity | Setup Time | Best For | Platform |
|--------|-----------|-----------|----------|----------|
| **Docker Compose** | Low | 3 min | Easy multi-platform | Linux, macOS, Windows |
| **Podman Quadlet** | Low | 2 min | Production Linux | Linux (systemd) |
| **Local Build** | Medium | 15 min | Development | Linux, macOS, Windows |

## Feature Comparison

### Startup & Management

| Feature | Docker | Podman | Local |
|---------|--------|--------|-------|
| Auto-start on boot | ✅ (via systemd) | ✅ (native) | ❌ |
| Manual startup | ✅ `compose up` | ✅ `systemctl start` | ✅ Direct run |
| Restart policy | ✅ always | ✅ on-failure | ❌ |
| Health checks | ✅ | ✅ | ✅ (built-in) |

### Logging & Monitoring

| Feature | Docker | Podman | Local |
|--------|--------|--------|-------|
| View logs | ✅ `compose logs` | ✅ `journalctl` | ✅ stdout |
| Real-time logs | ✅ `-f` flag | ✅ `-f` flag | ✅ Direct |
| Log rotation | ✅ (Docker) | ✅ (systemd) | Manual |
| Integration | Separate | systemd journal | Direct |

### System Integration

| Feature | Docker | Podman | Local |
|--------|--------|--------|-------|
| systemd integration | Wrapper only | Native | Direct |
| User isolation | Limited | Full | Full |
| Rootless mode | Limited | Full | N/A |
| Network namespace | Yes | Yes | No |
| Resource limits | Via Docker | Via systemd | Manual |

### Performance

| Metric | Docker | Podman | Local |
|--------|--------|--------|-------|
| Startup time | ~2-3 sec | ~1-2 sec | ~3-5 sec |
| Memory overhead | ~150MB | ~20MB | <10MB |
| Disk overhead | ~1GB | Minimal | Minimal |
| CPU idle usage | ~2-3% | <1% | <1% |

### Security

| Feature | Docker | Podman | Local |
|--------|--------|--------|-------|
| Rootless support | ⚠️ Limited | ✅ Full | N/A |
| User isolation | ⚠️ Via options | ✅ Native | ✅ Direct |
| Daemon privilege | ✅ Elevated | ✅ Minimal | ✅ None |
| SELinux support | Limited | Full | N/A |

## Platform Support

### Docker Compose

- ✅ Linux (all distributions)
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/CentOS 8+
  - Fedora 35+
  - Arch Linux
- ✅ macOS (Intel & Apple Silicon)
- ✅ Windows (with Docker Desktop)
- ✅ Cloud (AWS, Azure, GCP)

### Podman Quadlet

- ✅ Linux (systemd-based)
  - Ubuntu 20.04+
  - Debian 11+
  - RHEL/CentOS 8+
  - Fedora 35+
  - Arch Linux
- ⚠️ macOS (requires VM, limited)
- ⚠️ Windows (requires WSL2, limited)
- ⚠️ Cloud (requires systemd)

### Local Build

- ✅ Linux (all distributions)
- ✅ macOS (Intel & Apple Silicon)
- ✅ Windows (with dependencies)
- ⚠️ Cloud (requires build tools)

## Decision Matrix

### Choose Docker Compose if...

- ✅ You use macOS or Windows
- ✅ You want cross-platform portability
- ✅ You're already familiar with Docker
- ✅ You need multi-container setups
- ✅ You want the easiest setup
- ✅ You deploy to cloud platforms

### Choose Podman Quadlet if...

- ✅ You're on Linux with systemd
- ✅ You want native systemd integration
- ✅ You prefer minimal overhead
- ✅ You want rootless containers
- ✅ You need production deployments
- ✅ You value security and isolation

### Choose Local Build if...

- ✅ You want to contribute to development
- ✅ You need custom modifications
- ✅ You want maximum control
- ✅ You don't want containerization overhead
- ✅ You're testing changes
- ✅ You need multiple versions running

## Installation Requirements

### Docker Compose

```bash
# Ubuntu/Debian
sudo apt install docker.io docker-compose

# macOS
brew install docker docker-compose

# Windows: Use Docker Desktop
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

### Local Build

```bash
# Ubuntu/Debian
sudo apt install golang git gcc nodejs make ffmpeg
corepack enable

# macOS
brew install go git gcc make node ffmpeg
corepack enable
```

## Cost & Resources

### Overhead Comparison

**Docker Compose:**
- Docker daemon: ~150MB RAM
- Disk: ~1GB
- CPU (idle): ~2-3%

**Podman Quadlet:**
- Container runtime: ~20MB RAM
- Disk: Minimal
- CPU (idle): <1%

**Local Build:**
- Process only: <10MB RAM
- Disk: Minimal
- CPU (idle): <1%

## Migration Paths

### Docker to Podman

```bash
# Stop Docker
docker compose down

# Create directories
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}

# Copy data
cp -r ./config/* ~/.stash/config/
cp -r ./data/* ~/.stash/data/

# Setup Podman
bash podman/setup-quadlet.sh

# Verify
systemctl --user status stash.container
```

### Podman to Docker

```bash
# Stop Podman
systemctl --user stop stash.container

# Create deployment directory
mkdir -p ~/stash-docker
cd ~/stash-docker
cp docker/production/docker-compose.yml .
mkdir -p {config,data,metadata,cache,blobs,generated}

# Copy data
cp -r ~/.stash/* ./

# Start Docker
docker compose up -d
```

### Local to Container

```bash
# Stop local instance
kill %stash

# Export database
cp ~/.stash/stash.db ~/stash-backup.db

# Setup container deployment
# Then restore database if needed
```

## Workflow Examples

### Development Workflow

**Best: Local Build or Podman Quadlet**

```bash
# Make code changes
git checkout -b feature/my-feature
# Edit code...

# Rebuild locally
make build

# Test
./stash

# Or with Podman dev environment
python3 generate-quadlet.py stash-dev.config
systemctl --user restart stash.container
```

### Production Deployment

**Best: Podman Quadlet**

```bash
# Setup on server
sudo bash podman/setup-quadlet.sh system

# Behind reverse proxy
# Automated backups
# Monitoring with systemd
```

### Multi-Instance Setup

**Best: Podman Quadlet Template System**

```bash
# Create multiple configs
cp stash.config.template stash-media.config
cp stash.config.template stash-archive.config

# Generate quadlets
python3 generate-quadlet.py stash-media.config
python3 generate-quadlet.py stash-archive.config

# Manage independently
systemctl --user status stash-media.container
systemctl --user status stash-archive.container
```

### Quick Testing

**Best: Docker Compose**

```bash
cd ~/test-stash
docker compose up
# Test features
docker compose down
```

## Recommendation Summary

```
New to containerization?
└─ → Docker Compose (familiar, easy)

Linux production server?
└─ → Podman Quadlet (efficient, native)

Want minimal overhead?
└─ → Podman Quadlet (~20MB vs 150MB)

Need macOS/Windows?
└─ → Docker Compose (better support)

Contributing to Stash?
└─ → Local Build (fastest iteration)

Need multiple instances?
└─ → Podman Quadlet + Templates

Using cloud platform?
└─ → Docker Compose (more compatible)
```

## Performance Rankings

### Startup Time (Fastest to Slowest)
1. Podman Quadlet: ~1-2 sec
2. Docker Compose: ~2-3 sec
3. Local Build: ~3-5 sec

### Memory Efficiency (Best to Worst)
1. Local Build: <10MB overhead
2. Podman Quadlet: ~20MB overhead
3. Docker Compose: ~150MB overhead

### Ease of Use (Easiest to Hardest)
1. Docker Compose: Quick start, familiar
2. Podman Quadlet: Simple setup, native
3. Local Build: More complex

## See Also

- [Quick Start](#)
- [Docker Setup](#)
- [Podman Setup](#)
- [Template System](#)

## Resources

- [Docker Documentation](https://docs.docker.com)
- [Podman Documentation](https://docs.podman.io)
- [Stash Documentation](https://docs.stashapp.cc)
