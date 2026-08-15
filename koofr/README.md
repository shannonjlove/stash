# Stash on Koofr

Run [Stash](https://github.com/stashapp/stash) on any Linux host with Docker, and keep the **media library** on [Koofr](https://koofr.eu/) cloud storage.

Koofr is object/file storage, not a compute host. Stash still runs in Docker on a VPS, NAS, or local machine. rclone mounts your Koofr folder as `/data` inside Stash.

## What lives where

| Path | Location | Why |
| --- | --- | --- |
| `/data` | Koofr (`Stash/media` by default) | Videos and images |
| `/root/.stash` | Local `koofr/data/config` | `config.yml` and SQLite |
| `/generated` | Local `koofr/data/generated` | Previews, sprites, transcodes |
| `/cache`, `/blobs`, `/metadata` | Local `koofr/data/*` | Fast local writes |

Do not put the SQLite database or generated files on Koofr. Network filesystems corrupt SQLite, and transcodes are write-heavy.

## Quick start

1. Create a Koofr **app password** (not your login password) at  
   [https://app.koofr.net/app/admin/preferences/password](https://app.koofr.net/app/admin/preferences/password)
2. On the Linux host:

```bash
cd koofr
cp .env.example .env
# edit .env: KOOFR_USER and KOOFR_APP_PASSWORD
chmod +x deploy-koofr.sh setup-rclone.sh
./deploy-koofr.sh
```

3. Open `http://HOST:9999`
4. Upload media into Koofr folder `Stash/media` (Web UI, rclone, or WebDAV)
5. In Stash: **Settings → Tasks → Scan**

`deploy-koofr.sh` installs Docker and fuse3 if needed, writes `rclone.conf`, creates the remote folder, then starts Stash. It prefers the [rclone Docker volume plugin](https://rclone.org/docker/). If plugin install fails, it uses `docker-compose.sidecar.yml`.

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
| `docker-compose.yml` | Stash + rclone volume plugin |
| `docker-compose.sidecar.yml` | Stash + rclone FUSE sidecar |
| `.env.example` | Koofr credentials and paths |
| `rclone.conf.example` | rclone remote template |
| `config.yml.example` | oshash / sequential scan defaults |
| `deploy-koofr.sh` | End-to-end install |
| `setup-rclone.sh` | Build `rclone.conf` from `.env` |
| `stash-koofr.service` | Example systemd unit |

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
docker compose ps
docker compose logs -f stash
docker run --rm -v "$PWD/rclone.conf:/config/rclone/rclone.conf:ro" rclone/rclone:latest lsd koofr:
docker run --rm -v "$PWD/rclone.conf:/config/rclone/rclone.conf:ro" rclone/rclone:latest ls koofr:Stash/media
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
