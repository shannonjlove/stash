# Podman Quadlet Quick Start

Get Stash running as a systemd service in under 5 minutes.

## Quick Setup

### User Service (Recommended for most users)

```bash
# Run setup script
bash podman/setup-quadlet.sh

# Or manually:
mkdir -p ~/.config/containers/systemd ~/.stash/{config,data,metadata,cache,blobs,generated}
cp podman/quadlet/stash.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user enable stash.container
systemctl --user start stash.container
```

### System Service (Requires root)

```bash
# Run setup script
sudo bash podman/setup-quadlet.sh system

# Or manually:
sudo mkdir -p /etc/containers/systemd /etc/stash /var/lib/stash/{data,metadata,cache,blobs,generated}
sudo useradd -r -s /sbin/nologin stash
sudo cp podman/quadlet/stash-system.container /etc/containers/systemd/stash.container
sudo systemctl daemon-reload
sudo systemctl enable stash.container
sudo systemctl start stash.container
```

## Access

Open browser to: **http://localhost:9999**

## Basic Commands

```bash
# Check status (user service)
systemctl --user status stash.container

# Check status (system service)
sudo systemctl status stash.container

# View logs
journalctl --user-unit stash.container -f  # user
sudo journalctl -u stash.container -f      # system

# Restart
systemctl --user restart stash.container   # user
sudo systemctl restart stash.container     # system

# Stop
systemctl --user stop stash.container      # user
sudo systemctl stop stash.container        # system
```

## Troubleshooting

### Service won't start

```bash
# Check logs
journalctl --user-unit stash.container -n 50

# Manually test container
podman run -it stashapp/stash:latest /bin/sh
```

### Port already in use

Edit `~/.config/containers/systemd/stash.container` and change:

```ini
PublishPort=8080:9999
```

Then:
```bash
systemctl --user daemon-reload
systemctl --user restart stash.container
```

### Permission denied

Ensure directories exist and are writable:

```bash
mkdir -p ~/.stash/{config,data,metadata,cache,blobs,generated}
chmod 755 ~/.stash
```

## What's Next?

- Read full guide: [QUADLET_SETUP.md](QUADLET_SETUP.md)
- Check Stash docs: https://docs.stashapp.cc
- Install scrapers for metadata
- Set up reverse proxy for external access

---

**Need Help?**
- Discord: https://discord.gg/2TsNFKt
- Docs: https://docs.stashapp.cc
- Podman: https://docs.podman.io
