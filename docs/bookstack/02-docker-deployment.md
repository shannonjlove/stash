# Docker Deployment Guide

Complete guide for deploying Stash using Docker Compose.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 2GB+ RAM
- 10GB+ free disk space

## Installation Steps

### 1. Create Deployment Directory

```bash
mkdir -p ~/stash-deployment
cd ~/stash-deployment
```

### 2. Get Files

Copy from repository or download:

```bash
# Option A: From repository
cp /path/to/stash/docker/production/docker-compose.yml .
cp /path/to/stash/docker/production/.env.example .env

# Option B: Download from GitHub
curl -O https://raw.githubusercontent.com/stashapp/stash/develop/docker/production/docker-compose.yml
curl -O https://raw.githubusercontent.com/stashapp/stash/develop/docker/production/.env.example
mv .env.example .env
```

### 3. Create Directories

```bash
mkdir -p config data metadata cache blobs generated
```

### 4. Configure (Optional)

Edit `.env` to customize:

```ini
STASH_PORT=9999              # Change port if needed
TZ=Etc/UTC                   # Set your timezone
```

Edit `docker-compose.yml` to customize volumes:

```yaml
services:
  stash:
    volumes:
      - ./config:/root/.stash
      - ./data:/data              # Your media directory
      - ./metadata:/metadata
      - ./cache:/cache
      - ./blobs:/blobs
      - ./generated:/generated
```

### 5. Start Stash

```bash
docker compose up -d
```

### 6. Verify

```bash
docker compose ps
docker compose logs -f
```

## First Run

1. Navigate to http://localhost:9999
2. Select media directory to scan
3. Confirm database locations (defaults are fine)
4. Complete setup wizard
5. Start library scan: Settings → Library → Scan

## Management Commands

### Service Control

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f stash
```

### Container Operations

```bash
# Execute command in container
docker compose exec stash sh

# View container status
docker compose ps

# Remove volumes (clean reset)
docker compose down -v
```

## Environment Variables

Configuration via environment variables:

```ini
# Port
STASH_PORT=9999

# Timezone
TZ=America/New_York

# Logging
LOG_LEVEL=info

# Database
STASH_DATABASE=/root/.stash/stash.sqlite
```

## Data Backup

### Manual Backup

```bash
# Stop service
docker compose down

# Backup
tar -czf stash-backup-$(date +%Y%m%d).tar.gz config data metadata

# Restart
docker compose up -d
```

### Restore Backup

```bash
# Stop service
docker compose down

# Restore
tar -xzf stash-backup-20260710.tar.gz

# Restart
docker compose up -d
```

## Update Stash

### Update to Latest

```bash
# Pull latest image
docker compose pull

# Restart with new image
docker compose up -d

# Verify
docker compose logs
```

### Use Development Build

Edit `docker-compose.yml`:

```yaml
services:
  stash:
    image: stashapp/stash:develop
```

Then:

```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs stash

# Common issues:
# - Port already in use: Change STASH_PORT
# - Permission denied: Fix directory permissions
# - Database error: Remove volumes and restart

# Remove volumes (resets database)
docker compose down -v
docker compose up -d
```

### High Memory Usage

```bash
# Check resource usage
docker stats stash

# Limit memory in docker-compose.yml
services:
  stash:
    mem_limit: 2g
    memswap_limit: 4g
```

### Slow Performance

```bash
# Check if disk I/O is bottleneck
docker compose exec stash iostat -x 1 5

# Solutions:
# - Use faster storage (SSD)
# - Increase thread count in Settings
# - Split large library into multiple instances
```

## Advanced Configuration

### Custom Port Mapping

```yaml
ports:
  - "8080:9999"  # Access on port 8080 locally
```

### Additional Volumes

```yaml
volumes:
  - /mnt/media:/data
  - /mnt/metadata:/metadata
```

### Network Mode

For DLNA support:

```yaml
network_mode: host
# Remove ports: section if using network_mode: host
```

### Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '1'
      memory: 1G
```

## Security

### Change Default Port

Recommended to run on non-standard port:

```yaml
ports:
  - "19999:9999"  # Internal port 9999, external 19999
```

### Use Reverse Proxy

For external access, use NGINX or Traefik:

```nginx
server {
    server_name stash.example.com;
    
    location / {
        proxy_pass http://localhost:9999;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Enable Authentication

Set strong password in setup wizard.

## Performance Tuning

### Optimize Cache

```yaml
environment:
  - STASH_CACHE_SIZE=1000  # MB
```

### Thread Count

In UI: Settings → Tasks → Thread Count

### Database Optimization

```bash
# Optimize database
docker compose exec stash sqlite3 /root/.stash/stash.sqlite "PRAGMA optimize;"
```

## Docker Compose Lifecycle

```
docker compose up -d     # Start in background
    ↓
docker compose ps        # Check running
    ↓
docker compose logs -f   # Monitor
    ↓
docker compose down      # Stop and clean up
    ↓
docker compose down -v   # Stop and remove volumes
```

## Useful Snippets

### Complete docker-compose.yml Example

```yaml
version: '3.8'

services:
  stash:
    image: stashapp/stash:latest
    container_name: stash
    restart: unless-stopped
    ports:
      - "9999:9999"
    environment:
      - STASH_STASH=/data/
      - STASH_GENERATED=/generated/
      - STASH_METADATA=/metadata/
      - STASH_CACHE=/cache/
      - STASH_PORT=9999
      - TZ=Etc/UTC
    volumes:
      - ./config:/root/.stash
      - ./data:/data
      - ./metadata:/metadata
      - ./cache:/cache
      - ./blobs:/blobs
      - ./generated:/generated
    logging:
      driver: "json-file"
      options:
        max-file: "10"
        max-size: "2m"
```

### One-liner Setup

```bash
mkdir ~/stash && cd ~/stash && curl -O https://raw.githubusercontent.com/stashapp/stash/develop/docker/production/docker-compose.yml && mkdir -p config data metadata cache blobs generated && docker compose up -d
```

## See Also

- [Quick Start Guide](#)
- [Deployment Comparison](#)
- [Podman Alternative](#)
- [Troubleshooting](#)

## Resources

- [Official Docker Docs](https://docs.docker.com)
- [Stash Documentation](https://docs.stashapp.cc)
- [Docker Hub: Stash](https://hub.docker.com/r/stashapp/stash)
