# Podman Quadlets Setup Guide

Deploying Jellyfin and Stash with Podman quadlets for rootless, persistent operation with automatic systemd integration.

## Quick Start

```bash
# From oracle directory
chmod +x deploy-oracle-podman.sh
./deploy-oracle-podman.sh

# Optional: specify custom media library path
./deploy-oracle-podman.sh /mnt/media
```

## What Gets Deployed

### Quadlet Files

Three quadlet files deployed to `~/.config/containers/systemd/`:

| File | Purpose | Service |
|------|---------|---------|
| `media-network.network` | Shared Podman bridge network | `media-network.service` |
| `jellyfin.container` | Media server container | `jellyfin.service` |
| `stash.container` | Content management container | `stash.service` |

### Generated Systemd Services

Quadlets automatically generate systemd user service files:

```
~/.config/systemd/user/
├── jellyfin.service (generated from jellyfin.container)
├── stash.service (generated from stash.container)
└── media-network.service (generated from media-network.network)
```

### Persistent Volumes

```bash
# Created automatically
podman volume ls
# jellyfin_config, jellyfin_cache
# stash_config, stash_data, stash_metadata
# stash_cache, stash_blobs, stash_generated
```

## Key Features

✅ **Rootless Operation** - Run without root or Docker daemon
✅ **Systemd Integration** - Native systemd service management
✅ **User Lingering** - Services persist across logout
✅ **Auto-Start** - Services restart on boot automatically
✅ **Health Checks** - Built-in TCP/HTTP health monitoring
✅ **Resource Limits** - Memory and CPU constraints per container
✅ **Persistent Storage** - All data survives reboots
✅ **Easy Logging** - `journalctl` for centralized logs

## Service Management

### View Status

```bash
# All user services
systemctl --user list-units --type=service --all

# Specific service
systemctl --user status jellyfin.service

# With more detail
systemctl --user status jellyfin.service --no-pager -l
```

### View Logs

```bash
# Real-time logs
journalctl --user -u jellyfin.service -f

# Last 50 lines
journalctl --user -u jellyfin.service -n 50

# Stash logs
journalctl --user -u stash.service -f

# All media services
journalctl --user -u "media-*.service" -f
```

### Control Services

```bash
# Start service
systemctl --user start jellyfin.service

# Stop service
systemctl --user stop jellyfin.service

# Restart service
systemctl --user restart jellyfin.service

# Enable auto-start
systemctl --user enable jellyfin.service

# Disable auto-start
systemctl --user disable jellyfin.service
```

### Restart All Services

```bash
systemctl --user restart jellyfin.service stash.service
```

## Access Services

Once running (wait 30-60 seconds for startup):

- **Jellyfin:** http://localhost:8096
- **Stash:** http://localhost:9999

## Configuration

### Resource Limits

Edit quadlet files to adjust memory/CPU:

**jellyfin.container:**
```
Memory=1500M           # Memory allocation
MemoryLimit=1500M      # Maximum memory
CPUQuota=75%          # CPU allocation
```

**stash.container:**
```
Memory=1000M
MemoryLimit=1000M
CPUQuota=75%
```

### Health Checks

Modify health check parameters:

```
HealthCmd=curl -f http://localhost:8096/web/index.html || exit 1
HealthInterval=30s      # Check every 30 seconds
HealthRetries=3         # Fail after 3 retries
HealthStartPeriod=60s   # Grace period on startup
HealthTimeout=10s       # Timeout for each check
```

### Network Configuration

Media services use bridge network `media-net`:

```
Network=media-net
```

IP range: `10.88.0.0/24` (gateway: `10.88.0.1`)

### Persistent Storage Paths

Volume mappings in quadlets:

| Container Path | Volume Name | Purpose |
|---|---|---|
| `/config` | `jellyfin_config` | Jellyfin configuration |
| `/cache` | `jellyfin_cache` | Jellyfin cache |
| `/home/stash/.stash` | `stash_config` | Stash configuration |
| `/data` | `stash_data` | Stash database |
| `/metadata` | `stash_metadata` | Stash metadata |
| `/cache` | `stash_cache` | Stash cache |
| `/blobs` | `stash_blobs` | Stash blob storage |
| `/generated` | `stash_generated` | Generated content |
| `/media` (read-only) | `media-library` | Shared media library |

## User Lingering

Services persist across logout/reboot via user lingering:

```bash
# Check if enabled
loginctl show-user $USER | grep Linger

# Should show: Linger=yes

# Enable if needed
loginctl enable-linger $USER
```

With lingering enabled:
- Services continue running after you logout
- Services auto-start on system reboot
- No need for root or systemd system-wide services

## Updating Quadlets

1. Edit quadlet file:
   ```bash
   nano ~/.config/containers/systemd/jellyfin.container
   ```

2. Reload systemd:
   ```bash
   systemctl --user daemon-reload
   ```

3. Restart service:
   ```bash
   systemctl --user restart jellyfin.service
   ```

## Troubleshooting

### Services won't start

```bash
# Check logs
journalctl --user -u jellyfin.service -n 50

# Verify quadlet syntax
podman run --rm -v ~/.config/containers/systemd:/quadlets:z \
  quay.io/podman/podman quadlet --dry-run
```

### Lingering not enabled

```bash
# Enable
loginctl enable-linger $USER

# Verify
loginctl show-user $USER
# Should show: Linger=yes
```

### Container won't connect to network

```bash
# Check network exists
podman network ls
# media-net should be listed

# Inspect network
podman network inspect media-net

# Recreate if needed
podman network create media-net
```

### Out of memory

Check resource usage:
```bash
# Container stats
podman stats jellyfin stash

# System memory
free -h

# Increase limits in quadlet file
# Memory=2000M (increase from 1500M)
```

### Port already in use

```bash
# Check listening ports
netstat -tlnp | grep -E '8096|9999'

# Kill process using port
lsof -i :8096
kill -9 <PID>

# Or use different ports in quadlet:
# PublishPort=9096:8096
```

## Integration with 1Password

Store 1Password credentials for automated setup:

```bash
# Save 1Password token
export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"

# Create vault
op vault create "Oracle Media Servers"

# Store service credentials
op item create \
  --category login \
  --title "Jellyfin Admin" \
  --vault "Oracle Media Servers" \
  url="http://localhost:8096" \
  username=admin \
  password="your-strong-password"
```

## Monitoring

### Continuous monitoring

```bash
# Watch all media services
watch -n 2 'systemctl --user status jellyfin.service stash.service'

# Monitor logs in real-time
journalctl --user -u "jellyfin.service" -f &
journalctl --user -u "stash.service" -f &
```

### Health status

```bash
# Podman container health
podman ps --format "table {{.Names}}\t{{.Status}}"

# Systemd service status
systemctl --user list-units --type=service --state=running
```

## Backup & Restore

### Backup Volumes

```bash
# Backup Jellyfin config
podman run --rm -v jellyfin_config:/source:ro \
  -v $(pwd):/backup:Z \
  alpine tar czf /backup/jellyfin-backup.tar.gz -C /source .

# Backup Stash config
podman run --rm -v stash_config:/source:ro \
  -v $(pwd):/backup:Z \
  alpine tar czf /backup/stash-backup.tar.gz -C /source .
```

### Restore Volumes

```bash
# Restore Jellyfin config
podman run --rm -v jellyfin_config:/target:Z \
  -v $(pwd):/backup:ro,Z \
  alpine tar xzf /backup/jellyfin-backup.tar.gz -C /target

# Restore Stash config
podman run --rm -v stash_config:/target:Z \
  -v $(pwd):/backup:ro,Z \
  alpine tar xzf /backup/stash-backup.tar.gz -C /target
```

## References

- [Podman Quadlets Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Systemd User Services](https://wiki.archlinux.org/title/Systemd/User)
- [Podman Network Documentation](https://docs.podman.io/en/latest/markdown/podman-network.1.html)
- [Quadlet Examples](https://github.com/containers/podman/tree/main/contrib/quadlet)

---

**Last Updated:** 2026-07-28  
**Status:** Production Ready  
**Scope:** Oracle Cloud, Always Free tier
