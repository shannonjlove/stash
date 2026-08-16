# Stash on Koofr

Run [Stash](https://github.com/stashapp/stash) on any Linux host, and keep the **media library** on [Koofr](https://koofr.eu/) cloud storage.

Koofr is object/file storage, not a compute host. Stash still runs in a container on a VPS, NAS, or local machine. rclone mounts your Koofr folder as `/data` inside Stash.

For an always-on install, use **Podman quadlets** (`./setup-quadlet.sh`). Docker Compose remains available as an alternative.

## What lives where

| Path | Location | Why |
| --- | --- | --- |
| `/data` | Koofr (`Stash/media` by default) | Videos and images |
| `/root/.stash` | `~/.stash/config` (quadlet) or `koofr/data/config` (Compose) | `config.yml` and SQLite |
| `/generated` | `~/.stash/generated` or `koofr/data/generated` | Previews, sprites, transcodes |
| `/cache`, `/blobs`, `/metadata` | matching local dirs | Fast local writes |

Do not put the SQLite database or generated files on Koofr. Network filesystems corrupt SQLite, and transcodes are write-heavy.

## Quick start

1. Create a Koofr **app password** (not your login password) at  
   [https://app.koofr.net/app/admin/preferences/password](https://app.koofr.net/app/admin/preferences/password)
2. On the Linux host:

```bash
cd koofr
cp .env.example .env
# KOOFR_USER is the Koofr account email (not the app-password name)
# KOOFR_APP_PASSWORD is the 16-character Koofr app password
chmod +x setup-quadlet.sh setup-rclone.sh koofr-agent.sh
sudo ./setup-quadlet.sh system   # boot-time system units, always on
```

Docker Compose instead of quadlets:

```bash
./deploy-koofr.sh
```

3. Open `http://HOST:9999`
4. Upload media into Koofr folder `Stash/media` (Web UI, rclone, or WebDAV)
5. In Stash: **Settings → Tasks → Scan**

`setup-quadlet.sh system` installs `koofr-rclone.service` (Koofr mount + loopback RC API on `127.0.0.1:5572`) and `stash.service`, both `Restart=always`. The agent token is written to `/etc/stash/koofr-rc.env`. See [QUADLET.md](QUADLET.md).

`deploy-koofr.sh` is the Docker path: it prefers the [rclone Docker volume plugin](https://rclone.org/docker/) and falls back to `docker-compose.sidecar.yml`.

## Manual steps

```bash
cp .env.example .env
# fill KOOFR_USER and KOOFR_APP_PASSWORD
./setup-rclone.sh

# plugin path
sudo mkdir -p /var/lib/docker-plugins/rclone/config /var/lib/docker-plugins/rclone/cache
sudo cp rclone.conf /var/lib/docker-plugins/rclone/config/rclone.conf
docker plugin install rclone/docker-volume-rclone:amd64 args="-v" --alias rclone --grant-all-permissions
mkdir -p data/config data/metadata data/cache data/blobs data/generated
cp config.yml.example data/config/config.yml
docker compose up -d
```

Sidecar fallback:

```bash
sudo mkdir -p /mnt/koofr
echo user_allow_other | sudo tee -a /etc/fuse.conf
docker compose -f docker-compose.sidecar.yml up -d
```

## Files

| File | Purpose |
| --- | --- |
| `quadlet/*.container` | Always-on Podman units |
| `setup-quadlet.sh` | Install quadlets (user or system) |
| `QUADLET.md` | Quadlet operations |
| `docker-compose.yml` | Stash + rclone volume plugin |
| `docker-compose.sidecar.yml` | Stash + rclone FUSE sidecar |
| `.env.example` | Koofr credentials and paths |
| `rclone.conf.example` | rclone remote template |
| `config.yml.example` | oshash / sequential scan defaults |
| `deploy-koofr.sh` | Docker install |
| `setup-rclone.sh` | Build `rclone.conf` from `.env` |

`.env` and `rclone.conf` are gitignored.

## Cloud-friendly Stash settings

`config.yml.example` already sets:

- `calculate_md5: false` and `video_file_naming_algorithm: oshash` — MD5 would download every video
- `parallel_tasks: 1` and `sequential_scanning: true` — gentler on the Koofr API
- library path `/data`

Streaming uses rclone `--vfs-cache-mode full` so Stash can seek in remote files. Raise `RCLONE_VFS_CACHE_MAX_SIZE` if the host has spare SSD.

## WebDAV alternative

Koofr WebDAV is `https://app.koofr.net/dav/Koofr` with your email and the same app password. The native rclone `koofr` backend is faster; use WebDAV only if the Koofr API is blocked.

## Operations

```bash
systemctl --user status stash.service koofr-rclone.service
journalctl --user -u stash.service -f
podman run --rm -v "$PWD/rclone.conf:/config/rclone/rclone.conf:ro" docker.io/rclone/rclone:latest lsd koofr:
```

Stop:

```bash
docker compose down
# or
docker compose -f docker-compose.sidecar.yml down
```

## Security

- Use a Koofr **app password**, never the account password
- Keep Stash off the public internet, or put it behind a reverse proxy with auth
- `docker-compose.sidecar.yml` grants `SYS_ADMIN` and `/dev/fuse` so the FUSE mount is visible inside Stash ([stash#5137](https://github.com/stashapp/stash/issues/5137))
