# Podman Quadlet Template System

The template system allows you to generate customized Podman quadlet configurations for different deployment scenarios.

## Overview

The template system consists of:

1. **`stash.container.template`** - Base template with variables
2. **`stash.config.template`** - Configuration template with default values
3. **`generate-quadlet.py`** - Python script to generate instances
4. **Pre-generated files** - Ready-to-use `stash.container` and `stash-system.container`

## Use Cases

### Scenario 1: Multiple Stash Instances

Run multiple Stash services on the same system (different ports, data directories):

```bash
# Create configurations for each instance
cp podman/quadlet/stash.config.template stash-media.config
cp podman/quadlet/stash.config.template stash-archive.config

# Edit each config
nano stash-media.config      # CONTAINER_NAME=stash-media, PORT=9999
nano stash-archive.config    # CONTAINER_NAME=stash-archive, PORT=9998

# Generate quadlets
python3 podman/generate-quadlet.py stash-media.config
python3 podman/generate-quadlet.py stash-archive.config

# Install both
cp stash-media.container ~/.config/containers/systemd/
cp stash-archive.container ~/.config/containers/systemd/

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now stash-media.container
systemctl --user enable --now stash-archive.container
```

### Scenario 2: Development vs Production

Create separate configurations optimized for each environment:

**Development Configuration** (`stash-dev.config`):
```ini
CONTAINER_NAME=stash-dev
PORT=9998
IMAGE_TAG=develop
PULL_POLICY=always
# Minimal resource limits
```

**Production Configuration** (`stash-prod.config`):
```ini
CONTAINER_NAME=stash-prod
PORT=9999
IMAGE_TAG=latest
PULL_POLICY=missing
MEMORY_LIMIT=Memory=2g
CPU_QUOTA=CPUQuota=50%
```

Generate both:
```bash
python3 podman/generate-quadlet.py stash-dev.config
python3 podman/generate-quadlet.py stash-prod.config
```

### Scenario 3: Custom Storage Layout

Use external storage or custom directory structures:

**`stash-storage.config`**:
```ini
CONTAINER_NAME=stash
PORT=9999
# External storage
CONFIG_PATH=/mnt/storage/stash/config
DATA_PATH=/mnt/media
METADATA_PATH=/mnt/storage/stash/metadata
CACHE_PATH=/mnt/storage/stash/cache
BLOBS_PATH=/mnt/storage/stash/blobs
GENERATED_PATH=/mnt/storage/stash/generated
```

Generate:
```bash
python3 podman/generate-quadlet.py stash-storage.config
```

### Scenario 4: Resource-Constrained System

Optimize for low-memory or low-disk systems:

**`stash-minimal.config`**:
```ini
CONTAINER_NAME=stash
PORT=9999
IMAGE_TAG=latest
MEMORY_LIMIT=Memory=1g
MEMORY_SWAP_LIMIT=MemorySwap=2g
CPU_QUOTA=CPUQuota=25%
# Keep paths on faster storage
```

### Scenario 5: Team/Multi-User Setup

Each user has their own Stash instance:

```bash
# For user1
cp podman/quadlet/stash.config.template user1-stash.config
# Edit: CONTAINER_NAME=stash-user1, PORT=10001, paths in /home/user1

# For user2
cp podman/quadlet/stash.config.template user2-stash.config
# Edit: CONTAINER_NAME=stash-user2, PORT=10002, paths in /home/user2

# Generate both
python3 podman/generate-quadlet.py user1-stash.config
python3 podman/generate-quadlet.py user2-stash.config
```

## Template Variables

All variables available in the template:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DESCRIPTION` | Service description | Stash - Self-hosted media server | Custom name |
| `CONTAINER_NAME` | Container name | stash | stash-media |
| `IMAGE` | Docker image | stashapp/stash | stashapp/stash |
| `IMAGE_TAG` | Image tag | latest | develop, 0.28.0 |
| `PORT` | External port | 9999 | 8080, 9998 |
| `TIMEZONE` | Timezone | Etc/UTC | America/New_York |
| `RESTART_SEC` | Restart delay | 10s | 30s |
| `PULL_POLICY` | Pull policy | always | missing, never |
| `CONFIG_PATH` | Config directory | %h/.stash/config | /mnt/config |
| `DATA_PATH` | Media directory | %h/.stash/data | /media |
| `METADATA_PATH` | Metadata directory | %h/.stash/metadata | /mnt/metadata |
| `CACHE_PATH` | Cache directory | %h/.stash/cache | /mnt/cache |
| `BLOBS_PATH` | Blobs directory | %h/.stash/blobs | /mnt/blobs |
| `GENERATED_PATH` | Generated directory | %h/.stash/generated | /mnt/generated |
| `MEMORY_LIMIT` | Memory limit | (none) | Memory=2g |
| `MEMORY_SWAP_LIMIT` | Swap limit | (none) | MemorySwap=4g |
| `CPU_QUOTA` | CPU limit | (none) | CPUQuota=80% |
| `INSTALL_TARGET` | systemd target | default.target | multi-user.target |

Note: `%h` is expanded by systemd to the home directory.

## Quick Start

### 1. Copy Configuration Template

```bash
cd podman/quadlet
cp stash.config.template stash.config
```

### 2. Customize Configuration

```bash
nano stash.config
# Edit variables as needed
```

### 3. Generate Quadlet

```bash
cd ..
python3 generate-quadlet.py quadlet/stash.config
```

### 4. Preview (Optional)

```bash
python3 generate-quadlet.py quadlet/stash.config --preview
```

### 5. Install

```bash
cp stash.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user enable --now stash.container
```

## Generator Usage

### Basic Usage

```bash
# Generate with default output
python3 generate-quadlet.py config-file.config

# Output: config-file.container
```

### Advanced Usage

```bash
# Custom output filename
python3 generate-quadlet.py stash.config -o custom-stash.container

# With preview before writing
python3 generate-quadlet.py stash.config --preview

# Help
python3 generate-quadlet.py --help
```

## Workflow Example: Multiple Instances

```bash
#!/bin/bash
# Setup multiple Stash instances

# Create configs
for i in 1 2 3; do
    cat > stash-$i.config << EOF
CONTAINER_NAME=stash-$i
PORT=$((9999 + i - 1))
CONFIG_PATH=%h/.stash-$i/config
DATA_PATH=%h/.stash-$i/data
METADATA_PATH=%h/.stash-$i/metadata
CACHE_PATH=%h/.stash-$i/cache
BLOBS_PATH=%h/.stash-$i/blobs
GENERATED_PATH=%h/.stash-$i/generated
EOF

    # Create directories
    mkdir -p ~/.stash-$i/{config,data,metadata,cache,blobs,generated}

    # Generate quadlet
    python3 podman/generate-quadlet.py stash-$i.config
done

# Install all
cp stash-*.container ~/.config/containers/systemd/

# Enable and start
systemctl --user daemon-reload
systemctl --user enable stash-*.container
systemctl --user start stash-*.container
```

## Configuration Tips

### For Development
```ini
IMAGE_TAG=develop
PULL_POLICY=always
# No resource limits (use all available)
```

### For Production
```ini
IMAGE_TAG=latest
PULL_POLICY=missing
MEMORY_LIMIT=Memory=2g
CPU_QUOTA=CPUQuota=80%
```

### For Limited Resources
```ini
MEMORY_LIMIT=Memory=512m
MEMORY_SWAP_LIMIT=MemorySwap=1g
CPU_QUOTA=CPUQuota=25%
```

### For Custom Paths
```ini
# Use full paths, not %h for system-wide services
CONFIG_PATH=/etc/stash
DATA_PATH=/media/stash
METADATA_PATH=/var/lib/stash/metadata
```

## Troubleshooting

### Variables not replaced
Check that:
1. Variable names in config match exactly (case-sensitive)
2. Config file has `KEY=VALUE` format
3. No extra spaces around `=`

### Permission denied on output
The script creates files with 0644 permissions. If you need execution, manually set:
```bash
chmod +x generated-file.container
```

### Generator fails to load config
Ensure:
1. Config file exists
2. All required variables are present
3. Format is correct (KEY=VALUE)

### File size differs from pre-generated
This is expected if you:
1. Remove resource limit lines
2. Change image tag
3. Modify paths

Verify the output content is correct:
```bash
python3 generate-quadlet.py your.config --preview
```

## Comparing Generated Files

Check differences between generated and pre-generated:

```bash
# Generate from current config
python3 generate-quadlet.py stash.config -o generated-stash.container

# Compare with pre-generated
diff generated-stash.container quadlet/stash.container

# View specific differences
diff -u quadlet/stash.container generated-stash.container | head -20
```

## Advanced: Creating Custom Templates

Create your own template for different services:

1. Start with `stash.container.template`
2. Modify for your needs
3. Create new variables with `{{VARIABLE_NAME}}`
4. Document variables in new config template
5. Use generator with new template:

```bash
python3 generate-quadlet.py config.file -o output.container
```

## Best Practices

1. **Version Control**: Keep .config templates in git
   ```bash
   git add stash*.config
   git add podman/generate-quadlet.py
   ```

2. **Documentation**: Comment your configs
   ```ini
   # Production instance - high traffic media library
   CONTAINER_NAME=stash-prod
   ```

3. **Backups**: Keep generated files
   ```bash
   mkdir -p ~/.config/containers/systemd/backups
   cp *.container ~/.config/containers/systemd/backups/
   ```

4. **Testing**: Preview before installing
   ```bash
   python3 generate-quadlet.py stash.config --preview | less
   ```

5. **Naming**: Use descriptive config names
   ```bash
   stash-dev.config      # Development
   stash-prod.config     # Production
   stash-backup.config   # Backup instance
   ```

## Migration: Pre-generated to Templated

If using pre-generated files and want to switch to templates:

1. Create config file from current setup:
   ```bash
   cp quadlet/stash.config.template stash.config
   # Edit with current values
   ```

2. Generate new quadlet:
   ```bash
   python3 generate-quadlet.py stash.config -o stash-gen.container
   ```

3. Compare:
   ```bash
   diff quadlet/stash.container stash-gen.container
   ```

4. If identical, you can use template system going forward

---

**Version**: 1.0
**Last Updated**: 2026-07-10
