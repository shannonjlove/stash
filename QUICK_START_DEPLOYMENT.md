# Quick Start Deployment Guide

## Docker Deployment (Recommended - 2 minutes)

### 1. Prepare Deployment Directory

```bash
# Create a deployment directory
mkdir -p ~/stash-deployment
cd ~/stash-deployment

# Use the deploy script from the repository
bash /path/to/stash/docker/production/deploy.sh .
```

Or manually:

```bash
# Copy docker-compose.yml
cp /path/to/stash/docker/production/docker-compose.yml .
cp /path/to/stash/docker/production/.env.example .env

# Create directories
mkdir -p config data metadata cache blobs generated
```

### 2. Customize Configuration (Optional)

Edit `.env` or `docker-compose.yml`:
```bash
# Change port, timezone, or image version
nano .env
```

### 3. Start Stash

```bash
docker compose up -d
```

### 4. Access

- **Local**: http://localhost:9999
- **Network**: http://<YOUR-IP>:9999

### 5. First Run Setup

1. Select media directory to scan
2. Confirm database locations
3. Start library scan

---

## Local Build (Linux/macOS)

### 1. Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install golang git gcc nodejs make ffmpeg
corepack enable
```

**macOS:**
```bash
brew install go git gcc make node ffmpeg
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
# Access at http://localhost:9999
```

---

## Docker Compose Quick Commands

```bash
# Start Stash
docker compose up -d

# View logs
docker compose logs -f

# Stop Stash
docker compose down

# Update to latest version
docker compose pull
docker compose up -d

# Backup data
tar -czf backup.tar.gz config data metadata cache

# View status
docker compose ps
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Port 9999 in use | Change `ports:` in docker-compose.yml or use `STASH_PORT=8080` |
| FFmpeg not found | Already included in Docker; install locally with `brew/apt install ffmpeg` |
| Database errors | Remove volumes: `docker compose down -v && docker compose up -d` |
| Permission denied | Ensure directories have write permissions: `chmod 755 config data metadata cache blobs generated` |

---

## Next Steps

- 📖 Read full guide: [INSTALL_AND_DEPLOY.md](INSTALL_AND_DEPLOY.md)
- 🔌 Install community scrapers for metadata
- 🌐 Set up reverse proxy for external access
- 📚 Check [official documentation](https://docs.stashapp.cc)
- 💬 Join [community](https://discord.gg/2TsNFKt) for help

---

**Need Help?**
- Discord: https://discord.gg/2TsNFKt
- Forum: https://discourse.stashapp.cc
- Docs: https://docs.stashapp.cc
