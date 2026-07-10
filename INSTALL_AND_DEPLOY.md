# Stash Installation and Deployment Guide

This guide covers installing and deploying Stash on your system. Stash is a self-hosted webapp written in Go that organizes and serves your media collection.

## Prerequisites

### System Requirements
- 64-bit system (Linux, macOS, Windows, or Docker)
- At least 2GB RAM (4GB+ recommended)
- 10GB+ free disk space for data and database

### Required Software

#### For Docker Deployment (Recommended)
- Docker Engine 20.10+
- Docker Compose 2.0+

#### For Local Build
- Go 1.21+
- Node.js 18+ and pnpm
- GolangCI-Lint
- FFmpeg
- Git, gcc, and make

## Deployment Options

### Option 1: Docker Deployment (Recommended - Easiest)

Docker deployment is the simplest and most consistent way to deploy Stash.

#### 1. Create Deployment Directory

```bash
mkdir -p ~/stash-deployment
cd ~/stash-deployment
```

#### 2. Get docker-compose.yml

Copy the provided docker-compose.yml from the repository:

```bash
# Option A: From the repository
cp /path/to/stash/docker/production/docker-compose.yml .

# Option B: Download from GitHub
curl -o docker-compose.yml https://raw.githubusercontent.com/stashapp/stash/develop/docker/production/docker-compose.yml
```

#### 3. Create Required Directories

```bash
mkdir -p config data metadata cache blobs generated
```

#### 4. Configure (Optional)

Edit `docker-compose.yml` to adjust:
- **Port**: Change `9999` to your preferred port
- **Timezone**: Set `TZ` environment variable
- **Volume paths**: Adjust paths to your liking

#### 5. Start Stash

```bash
docker compose up -d
```

#### 6. Access Stash

Open your browser and navigate to:
- Local: `http://localhost:9999`
- Network: `http://<YOUR-LOCAL-IP>:9999`

#### 7. Initial Setup

On first launch, Stash will show a setup wizard:
1. Select a directory with media files to scan
2. Configure database and content locations (defaults are fine)
3. Complete the setup and start scanning

### Option 2: Linux Native Installation

#### Prerequisites Installation

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y golang git gcc nodejs make ffmpeg
# For pnpm (Node package manager)
corepack enable
```

**Arch Linux:**
```bash
sudo pacman -S go git gcc make nodejs ffmpeg --needed
corepack enable
```

#### Build Steps

1. **Clone/Navigate to Repository:**
   ```bash
   cd /path/to/stash
   ```

2. **Install UI Dependencies:**
   ```bash
   make pre-ui
   ```

3. **Generate Files:**
   ```bash
   make generate
   ```

4. **Build UI:**
   ```bash
   make ui
   ```

5. **Build Binaries (Release):**
   ```bash
   make build-release
   ```

   Or for development:
   ```bash
   make build
   ```

6. **Run Stash:**
   ```bash
   ./stash
   ```

   The application will start on `http://localhost:9999`

### Option 3: macOS Installation

#### Prerequisites

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install go git gcc make node ffmpeg
corepack enable
```

#### Build and Run

Follow the same steps as Linux Option 2.

#### Note on Security

On first run, you may see a security prompt. To bypass it:
- Control+Click the app
- Click "Open"
- Click "Open" again

### Option 4: Windows Installation

#### Prerequisites

1. Install [Go for Windows](https://golang.org/dl/)
2. Install [Node.js](https://nodejs.org/) and enable corepack:
   ```powershell
   corepack enable
   ```
3. Install [MinGW64](https://sourceforge.net/projects/mingw-w64/files/) (x86_64-posix-seh version)
4. Add MinGW64 to Windows Path
5. Install [FFmpeg](https://ffmpeg.org/download.html)
6. Install [GolangCI-Lint](https://golangci-lint.run/welcome/install/)
7. Install Git and Make via chocolatey or from source

#### Build and Run

In PowerShell or Command Prompt, replace `make` with `mingw32-make`:

```cmd
mingw32-make pre-ui
mingw32-make generate
mingw32-make ui
mingw32-make build-release
stash.exe
```

## Development Setup

For developers wanting to work on Stash:

### Quick Start

1. Install prerequisites (see above)
2. Navigate to repository root
3. In one terminal, start the backend:
   ```bash
   make server-start
   ```
4. In another terminal, start the frontend dev server:
   ```bash
   make ui-start
   ```
5. Open browser to `http://localhost:3000`

### Common Development Commands

- `make pre-ui` - Install UI dependencies
- `make generate` - Generate GraphQL and Go files
- `make ui` - Build the UI
- `make stash` - Build backend binary
- `make build` - Build both backend and frontend
- `make build-release` - Build optimized release versions
- `make lint` - Run linters
- `make fmt` - Format code
- `make validate` - Run all tests and checks
- `make server-start` - Start development server
- `make server-clean` - Clean development database
- `make ui-start` - Start UI dev server
- `make docker-build` - Build Docker image locally

## Configuration

### Environment Variables

Common environment variables for Docker or CLI:

- `STASH_PORT` - Port to run Stash on (default: 9999)
- `STASH_STASH` - Path to media directory (default: ~/.stash/stash)
- `STASH_GENERATED` - Path for generated content (default: ~/.stash/generated)
- `STASH_METADATA` - Path for metadata (default: ~/.stash/metadata)
- `STASH_CACHE` - Path for cache (default: ~/.stash/cache)
- `TZ` - Timezone for logging and scheduling

### First Run Setup

When Stash starts for the first time:

1. **Setup Wizard**: Choose a directory containing your media files
2. **Configure Paths**: Accept defaults or customize database/generated content paths
3. **Scan Library**: Navigate to `Settings → Library → Scan` to index your media
4. **Install FFmpeg**: If FFmpeg is missing, Stash will offer to download it
5. **Configure Scrapers**: Set up metadata sources (StashDB, community scrapers, etc.)

## Accessing from Other Machines

To access Stash from other machines on your network:

1. Find your local machine's IP address:
   ```bash
   # Linux/macOS
   ifconfig | grep inet

   # Windows
   ipconfig
   ```

2. Access from another machine:
   - `http://<YOUR-LOCAL-IP>:9999`

For external access or production deployment, consider:
- Using a reverse proxy (NGINX, Traefik)
- Setting up SSL/TLS certificates
- Implementing authentication/VPN

## Troubleshooting

### Port Already in Use

If port 9999 is already in use:

**Docker**: Edit docker-compose.yml and change:
```yaml
ports:
  - "9999:9999"  # Change first number to your desired port
```

**CLI**: Run with custom port:
```bash
STASH_PORT=8080 ./stash
```

### FFmpeg Issues

Stash requires FFmpeg for video processing:

- **Docker**: FFmpeg is included in the image
- **Linux**: Install from package manager (see Prerequisites)
- **macOS**: `brew install ffmpeg`
- **Windows**: Download from [FFmpeg website](https://ffmpeg.org/download.html)

### Database Issues

If experiencing database issues, try:

**Docker:**
```bash
docker compose down -v  # Remove volumes
docker compose up -d    # Start fresh
```

**CLI:**
```bash
rm -rf ~/.stash  # Remove config directory
./stash          # Start fresh
```

### Performance Issues

For large media libraries:

- Increase scan thread count in Settings
- Use a faster storage device (SSD recommended)
- Allocate more RAM if using Docker
- Consider creating multiple Stash instances for different collections

## Docker Maintenance

### View Logs

```bash
docker compose logs -f
```

### Stop Stash

```bash
docker compose down
```

### Update Stash

```bash
docker compose pull
docker compose up -d
```

### Backup Data

```bash
# Backup all Stash data
tar -czf stash-backup.tar.gz config data metadata cache blobs generated
```

## Additional Resources

- **Official Documentation**: https://docs.stashapp.cc
- **Community Forum**: https://discourse.stashapp.cc
- **Discord**: https://discord.gg/2TsNFKt
- **GitHub Issues**: https://github.com/stashapp/stash/issues
- **Community Scrapers**: https://github.com/stashapp/CommunityScrapers
- **StashDB**: https://stashdb.org

## Security Notes

- Stash is designed for local/trusted network use
- For external access, use a VPN or reverse proxy with authentication
- Keep FFmpeg and dependencies updated
- Regular backups are recommended for important data
- Stash stores configuration in `~/.stash` directory

## Getting Help

If you encounter issues:

1. Check the [official documentation](https://docs.stashapp.cc)
2. Search existing [GitHub issues](https://github.com/stashapp/stash/issues)
3. Ask on the [community forum](https://discourse.stashapp.cc)
4. Join the [Discord](https://discord.gg/2TsNFKt) for real-time help
5. Check in-app help with Shift+?

---

**Version**: Stash develop branch
**Last Updated**: 2026-07-10
