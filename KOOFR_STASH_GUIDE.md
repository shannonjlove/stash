# Stash + Koofr quick start

Keep the Stash media library on [Koofr](https://koofr.eu/) and run Stash in Docker on a Linux host.

Koofr stores files. It does not run containers. You still need a machine with Docker (VPS, NAS, or local Linux). rclone mounts `Stash/media` from Koofr as Stash's `/data` library. The database, cache, blobs, and generated files stay on local disk.

```
Linux host (Docker)
├── stash          :9999
│   ├── /data              → Koofr:Stash/media   (videos, images)
│   ├── /root/.stash       → ./koofr/data/config (SQLite, config.yml)
│   ├── /generated         → ./koofr/data/generated
│   └── /cache /blobs      → ./koofr/data/*
└── rclone VFS cache       → local SSD
```

## 15-minute setup

1. **App password** at [Koofr password settings](https://app.koofr.net/app/admin/preferences/password). Name it `stash-rclone`. Copy it once; Koofr will not show it again.
2. **Host packages:** Docker, fuse3, `/dev/fuse`.
3. **Deploy:**

```bash
git clone https://github.com/shannonjlove/stash.git
cd stash/koofr
cp .env.example .env
# set KOOFR_USER (email) and KOOFR_APP_PASSWORD
./deploy-koofr.sh
```

4. Open `http://HOST:9999`. Upload media to Koofr folder `Stash/media`, then **Scan**.

Full reference: [koofr/README.md](koofr/README.md).

## Why not store everything on Koofr

- SQLite on a network filesystem corrupts.
- Preview/transcode generation is write-heavy and latency-sensitive.
- `oshash` (64KB from each end of a file) is the scan hash. Full-file MD5 would pull every video from Koofr.

## Upload media

Koofr web app, rclone, or WebDAV (`https://app.koofr.net/dav/Koofr`):

```bash
docker run --rm \
  -v "$PWD/koofr/rclone.conf:/config/rclone/rclone.conf:ro" \
  -v /path/to/videos:/src:ro \
  rclone/rclone:latest copy /src koofr:Stash/media
```
