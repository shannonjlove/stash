# Podman Quadlet Setup for Stash

Podman quadlets are systemd unit files that define how to run containers with Podman. They provide a declarative way to manage Stash as a systemd service, with automatic startup, restart policies, and journal logging.

## What is a Quadlet?

A quadlet is a container-specific systemd unit file format that Podman uses to create systemd services. Key benefits:

- **Automatic startup**: Service starts on boot
- **Auto-restart**: Automatically restarts if the container crashes
- **systemd integration**: Full systemd lifecycle management
- **Journal logging**: Logs go to systemd journal
- **Easy management**: `systemctl` commands work normally
- **User or system scope**: Can run as user service or system-wide

## Quadlets Provided

### 1. User-level Quadlet (`stash.container`)

Runs Stash as a user service. Best for:
- Single-user systems
- Development/testing
- Home servers
- Non-critical deployments

**Paths**: 
- Config: `~/.stash/config`
- Data: `~/.stash/data`
- Generated: `~/.stash/generated`

### 2. System-level Quadlet (`stash-system.container`)

Runs Stash as a system service. Best for:
- Production deployments
- Multi-user systems
- Always-on servers
- System-managed services

**Paths**:
- Config: `/etc/stash`
- Data: `/var/lib/stash/data`
- Generated: `/var/lib/stash/generated`

## Installation

### Prerequisites

- **Podman 4.4+** (with quadlet support)
- **systemd** (most modern Linux distributions)
- Adequate disk space and permissions

Check Podman version:
```bash
podman --version
```

### Option A: User-level Service Setup

#### 1. Create Quadlet Directory

```bash
mkdir -p ~/.config/containers/systemd
```

#### 2. Install Quadlet File

```bash
cp podman/quadlet/stash.container ~/.config/containers/systemd/
```

Or create symlink for easy updates:
```bash
ln -s /path/to/stash/podman/quadlet/stash.container ~/.config/containers/systemd/
```

#### 3. Create Data Directories

```bash
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}
```

#### 4. Enable and Start Service

```bash
# Reload systemd
systemctl --user daemon-reload

# Enable on boot
systemctl --user enable stash.container

# Start service
systemctl --user start stash.container

# Check status
systemctl --user status stash.container
```

#### 5. Verify It's Running

```bash
# Check service status
systemctl --user is-active stash.container

# View recent logs
journalctl --user-unit stash.container -n 20

# Watch logs in real-time
journalctl --user-unit stash.container -f
```

Access Stash at: **http://localhost:9999**

### Option B: System-level Service Setup

#### 1. Create Quadlet Directory

```bash
sudo mkdir -p /etc/containers/systemd
```

#### 2. Install Quadlet File

```bash
sudo cp podman/quadlet/stash-system.container /etc/containers/systemd/stash.container
```

Or create symlink:
```bash
sudo ln -s /path/to/stash/podman/quadlet/stash-system.container /etc/containers/systemd/stash.container
```

#### 3. Create System User (if not exists)

```bash
sudo useradd -r -s /sbin/nologin stash 2>/dev/null || true
```

#### 4. Create Data Directories

```bash
sudo mkdir -p /etc/stash /var/lib/stash/{data,metadata,cache,blobs,generated}
sudo chown -R stash:stash /etc/stash /var/lib/stash
sudo chmod 750 /etc/stash /var/lib/stash
```

#### 5. Enable and Start Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable stash.container

# Start service
sudo systemctl start stash.container

# Check status
sudo systemctl status stash.container
```

#### 6. Verify It's Running

```bash
# Check service status
sudo systemctl is-active stash.container

# View recent logs
sudo journalctl -u stash.container -n 20

# Watch logs in real-time
sudo journalctl -u stash.container -f
```

Access Stash at: **http://localhost:9999**

## Service Management

### Common Commands

Replace `stash.container` with your service name. Add `--user` for user-level services.

```bash
# Check status
systemctl status stash.container

# Start service
systemctl start stash.container

# Stop service
systemctl stop stash.container

# Restart service
systemctl restart stash.container

# Enable on boot
systemctl enable stash.container

# Disable from boot
systemctl disable stash.container

# View logs
journalctl -u stash.container -f

# View last 50 lines
journalctl -u stash.container -n 50

# View logs since last boot
journalctl -u stash.container -b

# View logs from specific time
journalctl -u stash.container --since "2 hours ago"
```

### Stopping and Removing

```bash
# Stop the service
systemctl --user stop stash.container

# Remove from boot
systemctl --user disable stash.container

# Remove quadlet file
rm ~/.config/containers/systemd/stash.container

# Reload systemd
systemctl --user daemon-reload

# Remove data (if desired)
rm -rf ~/.stash
```

## Configuration

### Environment Variables

Edit the quadlet file to customize:

```ini
Environment=STASH_PORT=9999
Environment=TZ=Etc/UTC
Environment=STASH_STASH=/data/
```

### Custom Paths

Modify volume mounts in the quadlet:

```ini
# User-level example
Volume=/mnt/media:/data:rw

# System-level example
Volume=/media:/var/lib/stash/data:rw
```

### Resource Limits

Uncomment and adjust in the quadlet:

```ini
Memory=2g
MemorySwap=4g
CPUQuota=80%
```

### Port Changes

Change the port mapping:

```ini
PublishPort=8080:9999
```

After editing, reload and restart:

```bash
systemctl --user daemon-reload
systemctl --user restart stash.container
```

## Container Image Updates

### Update to Latest Version

```bash
# Pull latest image
podman pull stashapp/stash:latest

# Restart service (will use new image)
systemctl --user restart stash.container
```

Or enable automatic updates:

```ini
Pull=always
```

This is already enabled in the quadlets and will pull on each container creation.

### Use Development Build

Edit the quadlet:

```ini
Image=stashapp/stash:develop
```

Then:

```bash
systemctl --user daemon-reload
systemctl --user restart stash.container
```

## Troubleshooting

### Service Won't Start

Check logs:
```bash
journalctl --user-unit stash.container -n 50
```

Common issues:
- **Port 9999 in use**: Change `PublishPort` in quadlet
- **Permission denied**: Check directory ownership and permissions
- **Image not found**: Run `podman pull stashapp/stash:latest`

### Container Crashes

View logs:
```bash
journalctl --user-unit stash.container -f
```

Check container status:
```bash
podman ps -a | grep stash
```

View container logs:
```bash
podman logs -f stash
```

### Restart in Loop

If container keeps restarting, check:
1. FFmpeg is installed: `podman exec stash ffmpeg -version`
2. Data directories are writable: `ls -la ~/.stash/`
3. No corrupted database: `podman exec stash sqlite3 ~/.stash/stash.db .tables`

### High Memory Usage

Adjust limits in quadlet:
```ini
Memory=2g
MemorySwap=4g
```

Restart:
```bash
systemctl --user restart stash.container
```

## Backup

### Backup Data

```bash
# Stop service
systemctl --user stop stash.container

# Backup
tar -czf ~/stash-backup-$(date +%Y%m%d).tar.gz ~/.stash/

# Start service
systemctl --user start stash.container
```

### Restore Data

```bash
# Stop service
systemctl --user stop stash.container

# Restore
tar -xzf ~/stash-backup-20260710.tar.gz -C ~/

# Start service
systemctl --user start stash.container
```

## Advanced Configuration

### Health Check

Add to quadlet `[Service]` section:

```ini
ExecHealthCheck=/usr/bin/curl -f http://localhost:9999/ || exit 1
HealthCheckInterval=30s
```

### Custom Restart Policy

Edit quadlet:

```ini
RestartPolicy=on-failure
RestartSec=10s
RestartMaxAttempts=5
```

### Network Isolation

For enhanced security:

```ini
Network=private
ExposedPorts=9999/tcp
```

### Read-only Data Volume

Make data read-only (if desired):

```ini
Volume=%h/.stash/data:/data:ro
```

## Comparing with Docker Compose

| Feature | Quadlet | Docker Compose |
|---------|---------|----------------|
| **Setup Complexity** | Low | Low |
| **systemd Integration** | Native | Via systemd-docker |
| **Auto-restart** | Built-in | Built-in |
| **Resource Limits** | Via systemd | Via Docker |
| **Logging** | systemd journal | Docker logs |
| **Management** | systemctl | docker compose |
| **Multi-container** | No (needs netcat file) | Yes |
| **Security** | Native rootless | Via Docker daemon |
| **Distribution** | systemd native | Via podman/docker |

## Performance Tips

1. **Use volume caching**: Add `:cached` flag for frequently accessed volumes
2. **Limit logging**: Adjust log rotation with `--log-opt max-size`
3. **Pin image version**: Use specific version instead of `latest`
4. **Use tmpfs for cache**: `tmpfs:size=1g:/cache:rw`
5. **Enable user namespaces**: For enhanced security (rootless mode)

## Migration from Docker Compose

If migrating from Docker Compose:

```bash
# Stop Docker Compose
docker compose down

# Create directories for Podman
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}

# Copy data from Docker volumes (if needed)
docker cp stash:/root/.stash/config/. ~/.stash/config/

# Set up quadlet
cp podman/quadlet/stash.container ~/.config/containers/systemd/

# Start with systemd
systemctl --user daemon-reload
systemctl --user enable stash.container
systemctl --user start stash.container
```

## Additional Resources

- **Podman Documentation**: https://docs.podman.io
- **Systemd Quadlet Spec**: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
- **Stash Documentation**: https://docs.stashapp.cc
- **Podman Rootless**: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md

---

**Version**: 1.0
**Last Updated**: 2026-07-10
**Tested With**: Podman 4.4+, systemd 240+
