# CRITICAL REQUIREMENT: Podman Quadlets Only

## ⚠️ DO NOT USE DOCKER OR DOCKER-COMPOSE

This project uses **Podman with Quadlets** exclusively. All container configurations must use quadlet files, not Docker or docker-compose.

---

## Specifications

| Aspect | Specification |
|--------|---------------|
| **Container Runtime** | Podman (NOT Docker) |
| **Configuration Format** | Podman Quadlets (.quadlet files) |
| **Service Manager** | Systemd (native integration) |
| **Daemon Model** | Daemonless (Podman) |
| **Persistence** | Systemd user services + lingering |
| **Config Directory** | `~/.config/containers/systemd/` |

---

## Why Podman Quadlets?

### Advantages Over Docker

1. **Rootless by Default** - No daemon required, enhanced security
2. **Native Systemd Integration** - Quadlets generate .service files automatically
3. **Persistent Services** - Services survive user logout via lingering
4. **Simplified Configuration** - Single unit file per service
5. **Better Resource Control** - Native systemd resource limits
6. **Zero Docker Dependency** - Independent of Docker daemon

### Quadlet Benefits

- **Automatic Unit Generation** - .quadlet files auto-convert to systemd units
- **Service Coordination** - Use systemd dependencies and ordering
- **Restart Policies** - Built into systemd (OnFailure, Always, etc.)
- **Health Checks** - Integrated with systemd monitoring
- **Logging** - Journald integration by default
- **User Services** - Run as unprivileged user, persist across sessions

---

## Required Quadlet Files

### 1. **jellyfin.container**
```quadlet
[Unit]
Description=Jellyfin Media Server
After=network.target

[Container]
Image=jellyfin/jellyfin:latest
ContainerName=jellyfin
PublishPort=8096:8096
PublishPort=8920:8920
Volume=jellyfin_config:/config
Volume=jellyfin_cache:/cache
Volume=media-library:/media:ro
Environment=JELLYFIN_LOG_LEVEL=info
Memory=1500M

[Service]
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

### 2. **stash.container**
```quadlet
[Unit]
Description=Stash Content Management
After=network.target

[Container]
Image=stashapp/stash:latest
ContainerName=stash
PublishPort=9999:9999
Volume=stash_config:/home/stash/.stash
Volume=stash_data:/data
Volume=media-library:/media:ro
Environment=STASH_LOGGING_LEVEL=info
Memory=1000M

[Service]
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

### 3. **media-network.network**
```quadlet
[Unit]
Description=Media Services Network
Before=jellyfin.service stash.service

[Network]
NetworkName=media-net
Driver=bridge
```

---

## Setup & Persistence

### Enable User Lingering (REQUIRED for persistence)

```bash
loginctl enable-linger $USER
```

This allows systemd user services to:
- Continue running after user logout
- Auto-start on system reboot
- Survive session termination

### Deploy Quadlets

```bash
# Create quadlets directory
mkdir -p ~/.config/containers/systemd/

# Copy .quadlet files
cp *.quadlet ~/.config/containers/systemd/

# Reload systemd (auto-generates .service files)
systemctl --user daemon-reload

# Enable services
systemctl --user enable jellyfin.service stash.service

# Start services
systemctl --user start jellyfin.service stash.service

# Verify
systemctl --user status jellyfin.service stash.service
```

### Check Generated Units

Quadlets automatically create systemd units:

```bash
ls -la ~/.config/containers/systemd/
# jellyfin.quadlet → jellyfin.service
# stash.quadlet → stash.service
# media-network.quadlet → media-network.service
```

### Manage Services

```bash
# View status
systemctl --user status jellyfin.service

# View logs
journalctl --user -u jellyfin.service -f

# Restart
systemctl --user restart jellyfin.service

# Stop
systemctl --user stop jellyfin.service

# Enable auto-start
systemctl --user enable jellyfin.service
```

---

## Key Files & Locations

| Item | Location | Format |
|------|----------|--------|
| Quadlet Files | `~/.config/containers/systemd/` | `.quadlet` |
| Generated Units | `~/.config/systemd/user/` | `.service` |
| Podman Volumes | `/var/lib/containers/storage/volumes/` | Podman managed |
| Service Logs | journalctl | systemd native |
| Configuration | Quadlet variables | Environment= fields |

---

## Migration from Docker

**OLD (docker-compose.yml):**
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    ports:
      - "8096:8096"
    volumes:
      - jellyfin_config:/config
    restart: on-failure
```

**NEW (jellyfin.quadlet):**
```quadlet
[Container]
Image=jellyfin/jellyfin:latest
PublishPort=8096:8096
Volume=jellyfin_config:/config

[Service]
Restart=on-failure
```

---

## Verification Checklist

- [ ] No `docker` commands used
- [ ] No `docker-compose.yml` file present
- [ ] All services use `.quadlet` files
- [ ] Quadlets in `~/.config/containers/systemd/`
- [ ] `loginctl enable-linger $USER` executed
- [ ] Services enabled with `systemctl --user enable`
- [ ] Services managed via `systemctl --user`
- [ ] Logs viewed with `journalctl --user`

---

## Troubleshooting

### Services not persisting after logout
```bash
# Check if lingering is enabled
loginctl show-user $USER
# Should show: Linger=yes

# Enable if needed
loginctl enable-linger $USER
```

### Quadlets not generating units
```bash
# Reload systemd
systemctl --user daemon-reload

# Verify quadlet syntax
podman run --rm -v ~/.config/containers/systemd:/quadlets:z \
  docker.io/containers/podman-quadlets:latest
```

### Service won't start
```bash
# Check logs
journalctl --user -u jellyfin.service -n 50

# Validate quadlet file
podman quadlet --dry-run jellyfin.quadlet
```

---

## References

- [Podman Quadlets Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Systemd User Services](https://wiki.archlinux.org/title/Systemd/User)
- [Podman User Guide](https://docs.podman.io/en/latest/)
- [Quadlet Examples](https://github.com/containers/podman/tree/main/contrib/quadlet)

---

**Document Status:** ACTIVE  
**Effective Date:** 2026-07-28  
**Last Updated:** 2026-07-28  
**Scope:** All Oracle deployments, Jellyfin, Stash infrastructure  
**Priority:** CRITICAL - All implementations must comply
