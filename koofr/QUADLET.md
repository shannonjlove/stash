# Stash Podman quadlets (always-on)

These units keep Stash running under systemd. rclone mounts Koofr as `/data`. Local disk holds SQLite, cache, blobs, and generated files.

Quadlet files in `koofr/quadlet/` generate:

| Unit | Role |
| --- | --- |
| `koofr-rclone.service` | FUSE mount of Koofr at `/mnt/koofr` (system) or `~/.stash/koofr` (user) |
| `koofr-rc.service` | rclone RC API on `127.0.0.1:5572` (read + write) |
| `stash.service` | Stash UI on port 9999, library = Koofr mount |

| Mode | Units | Starts | Survives logout |
| --- | --- | --- | --- |
| User (default) | `~/.config/containers/systemd/` | `default.target` + linger | Yes, after `loginctl enable-linger` |
| System | `/etc/containers/systemd/` | `multi-user.target` | Yes (boot) |

## Install

```bash
cd koofr
cp .env.example .env
# set KOOFR_USER and KOOFR_APP_PASSWORD

# User service (recommended on a personal machine)
./setup-quadlet.sh

# Or system-wide on a VPS (always-on at boot)
sudo ./setup-quadlet.sh system
```

`setup-quadlet.sh` writes `rclone.conf`, generates a `cursor-agent` RC API token in `koofr-rc.env`, creates `Stash/media` on Koofr, and starts the units with `Restart=always`.

Agent API (loopback):

```bash
./koofr-agent.sh lsd
./koofr-agent.sh lsd Stash/media
./koofr-agent.sh rc operations/about fs=koofr:
```

## Manual user install

```bash
mkdir -p ~/.config/containers/systemd \
  ~/.stash/{config,koofr,metadata,cache,blobs,generated,rclone-vfs}
cp .env ~/.stash/koofr.env
cp rclone.conf ~/.stash/rclone.conf
cp config.yml.example ~/.stash/config/config.yml
cp quadlet/koofr-rclone.container quadlet/stash.container ~/.config/containers/systemd/
loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now koofr-rclone.service stash.service
```

## Live behavior

- `Restart=always` restarts Stash and the Koofr mount after a crash
- User linger keeps the services running after SSH logout
- System units start at boot
- `Notify=healthy` on rclone so Stash waits until the mount works
- `AutoUpdate=registry` plus `podman-auto-update.timer` pulls new images

## Commands

User:

```bash
systemctl --user status stash.service koofr-rclone.service
journalctl --user -u stash.service -f
systemctl --user restart stash.service
podman ps
```

System:

```bash
systemctl status stash.service koofr-rclone.service
journalctl -u stash.service -f
sudo systemctl restart stash.service
```

Stop (does not disable):

```bash
systemctl --user stop stash.service koofr-rclone.service
```

Disable auto-start:

```bash
systemctl --user disable --now stash.service koofr-rclone.service
```

## Paths

User:

| Host | Container |
| --- | --- |
| `~/.stash/koofr` | `/data` (Koofr) |
| `~/.stash/config` | `/root/.stash` |
| `~/.stash/generated` | `/generated` |

System:

| Host | Container |
| --- | --- |
| `/mnt/koofr` | `/data` (Koofr) |
| `/var/lib/stash/config` | `/root/.stash` |
| `/var/lib/stash/generated` | `/generated` |

## Requirements

- Podman 4.4+
- systemd
- fuse3 and `/dev/fuse`
- `user_allow_other` in `/etc/fuse.conf`
- Koofr app password
