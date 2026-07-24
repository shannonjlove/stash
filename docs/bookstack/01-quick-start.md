# Quick Start: Deploy Stash

Get Stash running in minutes with these quick start guides.

## Docker Compose (Fastest - 3 minutes)

### 1. Create Deployment Directory

```bash
mkdir -p ~/stash-deployment
cd ~/stash-deployment
```

### 2. Get Configuration

```bash
# Copy docker-compose file and create directories
cp /path/to/stash/docker/production/docker-compose.yml .
mkdir -p config data metadata cache blobs generated
```

### 3. Start Stash

```bash
docker compose up -d
```

### 4. Access

Open browser to: **http://localhost:9999**

### 5. Initial Setup

1. Select a directory with media files (or create test directory)
2. Confirm default database locations
3. Complete setup wizard

## Podman Quadlet (Native systemd - 2 minutes)

### 1. Run Setup Script

```bash
bash /path/to/stash/podman/setup-quadlet.sh
```

### 2. Access

Open browser to: **http://localhost:9999**

### 3. Verify Service

```bash
systemctl --user status stash.container
```

## Local Build (Development - 15 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt install golang git gcc nodejs make ffmpeg
corepack enable
```

### 2. Build

```bash
cd /path/to/stash
make pre-ui
make generate
make ui
make build-release
```

### 3. Run

```bash
./stash
```

Access at: **http://localhost:9999**

---

## Choose Your Method

| Method | Time | Best For | Platform |
|--------|------|----------|----------|
| **Docker Compose** | 3 min | Easy setup, multi-platform | Linux, macOS, Windows |
| **Podman Quadlet** | 2 min | Production, systemd users | Linux |
| **Local Build** | 15 min | Development, customization | Linux, macOS, Windows |

## Troubleshooting

### Port Already in Use

```bash
# Docker: Edit docker-compose.yml
# ports:
#   - "8080:9999"  # Change 9999 to 8080

# Podman: Edit ~/.config/containers/systemd/stash.container
# PublishPort=8080:9999

# Local: Start on different port
STASH_PORT=8080 ./stash
```

### FFmpeg Not Found

```bash
# Docker: Included automatically
# Podman: Included automatically
# Local: Install
sudo apt install ffmpeg  # Debian/Ubuntu
brew install ffmpeg      # macOS
```

## Next Steps

1. ✅ Stash is running
2. 📁 Scan your media library (Settings → Library → Scan)
3. 🏷️ Tag and organize content
4. 🔌 Install scrapers for metadata
5. 🌐 Set up reverse proxy for external access (optional)

## Need Help?

- **Docs**: https://docs.stashapp.cc
- **Discord**: https://discord.gg/2TsNFKt
- **Forum**: https://discourse.stashapp.cc
- **GitHub Issues**: https://github.com/stashapp/stash/issues

---

**Ready to dig deeper?**
- [Full Installation Guide](#)
- [Docker Setup](#)
- [Podman Setup](#)
- [Deployment Comparison](#)
