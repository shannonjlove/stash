# Podman Quadlet Deployment Guide

Deploy Stash as a native systemd service using Podman quadlets.

## What is a Quadlet?

A quadlet is a systemd unit file that Podman uses to create containers. Benefits:

- ✅ Native systemd integration
- ✅ Auto-restart on failure
- ✅ Journal logging
- ✅ Service management with `systemctl`
- ✅ Minimal overhead (~20MB)
- ✅ Rootless mode support

## Prerequisites

- Podman 4.4+
- systemd
- 2GB+ RAM
- 10GB+ free disk space

## Quick Setup (2 minutes)

### Automated Setup

```bash
# User service (recommended)
bash /path/to/stash/podman/setup-quadlet.sh

# OR system-wide service (requires root)
sudo bash /path/to/stash/podman/setup-quadlet.sh system
```

### Manual Setup

**User Service:**

```bash
# Create directories
mkdir -p ~/.config/containers/systemd
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}

# Copy quadlet
cp /path/to/stash/podman/quadlet/stash.container ~/.config/containers/systemd/

# Enable and start
systemctl --user daemon-reload
systemctl --user enable stash.container
systemctl --user start stash.container
```

**System Service:**

```bash
# Create user
sudo useradd -r -s /sbin/nologin stash 2>/dev/null || true

# Create directories
sudo mkdir -p /etc/containers/systemd
sudo mkdir -p /etc/stash /var/lib/stash/{data,metadata,cache,blobs,generated}
sudo chown -R stash:stash /etc/stash /var/lib/stash

# Copy quadlet
sudo cp /path/to/stash/podman/quadlet/stash-system.container /etc/containers/systemd/stash.container

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable stash.container
sudo systemctl start stash.container
```

## Verification

### Check Service Status

```bash
# User service
systemctl --user status stash.container

# System service
sudo systemctl status stash.container
```

### View Logs

```bash
# Real-time logs
journalctl --user-unit stash.container -f  # user
sudo journalctl -u stash.container -f      # system

# Recent logs
journalctl --user-unit stash.container -n 50
```

### Test Connection

```bash
curl http://localhost:9999
```

## Access

Open browser to: **http://localhost:9999**

## Service Management

### Common Commands

```bash
# User service commands (add --user flag)

# Status
systemctl --user status stash.container

# Start
systemctl --user start stash.container

# Stop
systemctl --user stop stash.container

# Restart
systemctl --user restart stash.container

# Enable on boot
systemctl --user enable stash.container

# Disable from boot
systemctl --user disable stash.container
```

### System Service Commands

Replace `--user` with `sudo` for system services:

```bash
systemctl status stash.container
sudo systemctl stop stash.container
sudo systemctl restart stash.container
```

## Configuration

### Edit Service

Edit quadlet file to customize:

**User Service:**
```bash
nano ~/.config/containers/systemd/stash.container
```

**System Service:**
```bash
sudo nano /etc/containers/systemd/stash.container
```

### Common Changes

**Change Port:**

```ini
PublishPort=8080:9999
```

**Change Timezone:**

```ini
Environment=TZ=America/New_York
```

**Set Memory Limit:**

```ini
Memory=2g
MemorySwap=4g
CPUQuota=80%
```

### Apply Changes

```bash
systemctl --user daemon-reload
systemctl --user restart stash.container
```

## Template System

Generate custom quadlet configurations:

### Create Custom Config

```bash
cp /path/to/stash/podman/quadlet/stash.config.template my-stash.config
nano my-stash.config  # Edit as needed
```

### Generate Quadlet

```bash
python3 /path/to/stash/podman/generate-quadlet.py my-stash.config
```

### Multiple Instances

```bash
# Create configs for each instance
cp stash.config.template stash-media.config
cp stash.config.template stash-archive.config

# Edit each with different:
# - CONTAINER_NAME
# - PORT
# - Data paths

# Generate all
python3 generate-quadlet.py stash-media.config
python3 generate-quadlet.py stash-archive.config

# Install and enable all
```

## Data Management

### Backup

```bash
# Stop service
systemctl --user stop stash.container

# Backup (user service)
tar -czf stash-backup-$(date +%Y%m%d).tar.gz ~/.stash/

# Restart
systemctl --user start stash.container
```

### Restore

```bash
# Stop service
systemctl --user stop stash.container

# Restore
tar -xzf stash-backup-20260710.tar.gz -C ~/

# Restart
systemctl --user start stash.container
```

### Move Data Directory

```bash
# Stop service
systemctl --user stop stash.container

# Move data
mv ~/.stash /new/location/

# Edit quadlet paths
# Volume=/new/location/.stash/...

# Reload and start
systemctl --user daemon-reload
systemctl --user start stash.container
```

## Update Stash

### Update Image

```bash
# Pull latest
podman pull stashapp/stash:latest

# Restart
systemctl --user restart stash.container
```

### Use Development Build

Edit quadlet:

```ini
Image=stashapp/stash:develop
Pull=always
```

Restart:

```bash
systemctl --user daemon-reload
systemctl --user restart stash.container
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl --user-unit stash.container -n 50

# Common issues:
# - Port already in use: Change PublishPort
# - Directory permissions: Check ownership
# - Image not found: Run podman pull stashapp/stash:latest
```

### Permission Denied

```bash
# Ensure directories exist and are writable
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}
chmod 755 ~/.stash

# For system service
sudo chown -R stash:stash /var/lib/stash
sudo chmod 750 /var/lib/stash
```

### Container Restarts Constantly

```bash
# Check logs for errors
journalctl --user-unit stash.container -f

# Check container directly
podman logs -f stash

# Verify database isn't corrupted
podman exec stash sqlite3 ~/.stash/stash.db .tables
```

### High Memory Usage

```bash
# Check current usage
podman stats stash

# Set memory limits in quadlet
Memory=2g

# Restart
systemctl --user daemon-reload
systemctl --user restart stash.container
```

## Performance Tuning

### Resource Limits

```ini
Memory=2g
MemorySwap=4g
CPUQuota=80%
```

### Disable Auto-Pull

For offline systems, change:

```ini
Pull=never
```

### Enable Caching

```ini
Volume=%h/.cache/stash:/tmp:rw
```

## Security

### Run Rootless

Podman quadlets run rootless by default for user services.

For system services, use dedicated user:

```bash
sudo useradd -r stash
# In quadlet: User=stash
```

### Restrict Port Access

Use firewall to restrict external access:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 9999
```

### Use Reverse Proxy

For external access:

```nginx
server {
    server_name stash.example.com;
    location / {
        proxy_pass http://localhost:9999;
    }
}
```

## Comparing with Docker Compose

| Feature | Podman | Docker |
|---------|--------|--------|
| Setup Time | 2 min | 3 min |
| Overhead | 20MB | 150MB |
| systemd Integration | Native | Via wrapper |
| Platform | Linux only | Multi-platform |
| Rootless | Yes | Limited |
| Logging | systemd journal | Docker logs |

## See Also

- [Quick Start](#)
- [Template System](#)
- [Management Commands](#)
- [Troubleshooting](#)

## Resources

- [Podman Documentation](https://docs.podman.io)
- [systemd Quadlet Spec](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Stash Documentation](https://docs.stashapp.cc)
