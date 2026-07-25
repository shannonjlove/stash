# Stash Import Scripts

Tools for importing Stash deployment documentation into BookStack, Paperless, or both.

## Quick Start

### Import to Both BookStack and Paperless

```bash
# Set environment variables
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=your_bookstack_token
export PAPERLESS_URL=https://paperless.example.com
export PAPERLESS_TOKEN=your_paperless_token

# Run import
./import-all.sh --both
```

### Import to BookStack Only

```bash
./import-all.sh --bookstack https://bookstack.example.com your_token
```

### Import to Paperless Only

```bash
./import-all.sh --paperless https://paperless.example.com your_token
```

## Scripts

### import-all.sh

Unified import tool that can orchestrate imports to BookStack, Paperless, or both.

**Usage:**
```bash
./import-all.sh --bookstack <url> <token>
./import-all.sh --paperless <url> <token>
./import-all.sh --both <bs-url> <bs-token> <pl-url> <pl-token>
./import-all.sh --help
```

**Features:**
- Single command to import to multiple systems
- Environment variable support for credentials
- Detailed progress reporting
- Automatic error handling

### import-bookstack.sh

Import Stash documentation into BookStack via REST API.

**Usage:**
```bash
./import-bookstack.sh <url> <token>
```

**Environment Variables:**
```bash
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=your_token
./import-bookstack.sh
```

**What it creates:**
- Shelf: "Stash Documentation"
- Books:
  - Getting Started (Quick Start, Deployment Methods, Installation Guide)
  - Docker Deployment (Docker Compose Setup)
  - Podman Deployment (Quadlet Setup, Configuration, Quick Start, Templates)
  - Advanced Features (1Password Integration, Deploy Script Guide)

**Requirements:**
- curl
- jq (for JSON parsing)

### import-paperless.sh

Import Stash documentation into Paperless as searchable PDFs.

**Usage:**
```bash
./import-paperless.sh <url> <token>
```

**Environment Variables:**
```bash
export PAPERLESS_URL=https://paperless.example.com
export PAPERLESS_TOKEN=your_token
./import-paperless.sh
```

**What it creates:**
- PDF documents for all markdown files
- Tags for organization:
  - `stash`: All Stash-related documents
  - `deployment`: Deployment guides
  - `docker`: Docker-specific docs
  - `podman`: Podman-specific docs
  - `guide`: Setup and configuration guides
  - `quick-start`: Quick start guides
  - `security`: Security-related documents

**Requirements:**
- curl
- pandoc (for markdown → PDF conversion)
- wkhtmltopdf (optional, for better PDF quality)

**Installation:**
```bash
# Install pandoc (required)
sudo apt install pandoc

# Install wkhtmltopdf (optional, for better quality)
sudo apt install wkhtmltopdf
```

## Getting API Tokens

### BookStack

1. Log in to BookStack as an admin
2. Go to Settings → API Tokens
3. Create a new token
4. Copy the token value

### Paperless

1. Log in to Paperless as an admin
2. Go to Settings → API
3. Create a new API token
4. Copy the token value

## Documents Imported

### Core Documentation
- `QUICK_START_DEPLOYMENT.md` - 3-5 minute quick start
- `INSTALL_AND_DEPLOY.md` - Complete installation guide for all platforms
- `DEPLOYMENT_COMPARISON.md` - Comparison of deployment methods

### Deployment Guides
- `docs/bookstack/02-docker-deployment.md` - Docker setup guide
- `docs/bookstack/03-podman-deployment.md` - Podman setup guide
- `podman/QUADLET_SETUP.md` - Advanced Podman Quadlet configuration
- `podman/QUADLET_QUICK_START.md` - Podman quick start
- `podman/TEMPLATE_USAGE.md` - Template system for customization

### Advanced Features
- `docs/1password/1PASSWORD_SETUP.md` - Full 1Password integration
- `docs/1password/QUICK_START.md` - 1Password quick start
- `DEPLOY_GUIDE.md` - Deploy script usage guide

## Workflow Examples

### Initial Documentation Setup

```bash
# Setup BookStack
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=token_from_step_1
./import-all.sh --bookstack

# Setup Paperless
export PAPERLESS_URL=https://paperless.example.com
export PAPERLESS_TOKEN=token_from_step_2
./import-all.sh --paperless
```

### Complete Setup with Both Systems

```bash
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=abc123
export PAPERLESS_URL=https://paperless.example.com
export PAPERLESS_TOKEN=def456

./import-all.sh --both
```

### Update Documentation

To update documentation in BookStack or Paperless after changes to source files:

1. Manually update pages in BookStack, or
2. Re-run the import script:
```bash
./import-all.sh --bookstack $BOOKSTACK_URL $BOOKSTACK_TOKEN
```

## Troubleshooting

### Connection Errors

**Error:** "Failed to connect to BookStack/Paperless"

**Solution:**
- Verify URL is correct (include https://)
- Verify token is valid and not expired
- Check firewall/network access to server

### Token Errors

**Error:** "Unauthorized" or "Invalid token"

**Solution:**
- Regenerate API token in web interface
- Ensure token is copied completely
- Check for trailing spaces

### Missing Commands

**Error:** "jq not installed" or "pandoc not installed"

**Solution:**
```bash
# For jq
sudo apt install jq

# For pandoc
sudo apt install pandoc

# For wkhtmltopdf (optional)
sudo apt install wkhtmltopdf
```

### PDF Conversion Fails

**Error:** "Failed to create PDF"

**Solution:**
- Install pandoc: `sudo apt install pandoc`
- For better quality, install wkhtmltopdf: `sudo apt install wkhtmltopdf`
- Check available disk space

### Large Document Timeout

**Error:** Request timeout during upload

**Solution:**
- Run individual imports instead of `--both`
- Check server load and disk space
- Increase script timeout if needed

## API Details

### BookStack API

Creates resources in this order:
1. Shelf (if supporting multi-book organization)
2. Books (top-level organization)
3. Chapters (within books)
4. Pages (content within chapters)

API Endpoints used:
- `POST /api/shelves` - Create shelf
- `POST /api/books` - Create book
- `POST /api/chapters` - Create chapter
- `POST /api/pages` - Create page

### Paperless API

Uploads documents with metadata:
1. Creates or retrieves tags
2. Converts markdown to PDF
3. Uploads PDF with tags and title

API Endpoints used:
- `POST /api/tags/` - Create/list tags
- `POST /api/documents/post_document/` - Upload document
- `GET /api/documents/` - List documents

## Best Practices

1. **Test First**
   - Run on test instance before production
   - Verify structure after import
   - Check for missing or malformed content

2. **Organize Tags in Paperless**
   - Use tags to organize documents
   - Create custom tags for your workflow
   - Archive imported documents for reference

3. **Link Between Systems**
   - Link to Paperless documents from BookStack
   - Add cross-references in both systems
   - Keep versions in sync

4. **Backup Before Import**
   - Export existing documentation
   - Create system backups
   - Keep git history for rollback

5. **Regular Updates**
   - Re-run imports after documentation changes
   - Version your documentation
   - Track changes in git

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review BookStack/Paperless logs
3. Verify API token permissions
4. Check network connectivity

## Examples

### Full Workflow

```bash
#!/bin/bash
# setup-documentation.sh

set -e

# Configuration
BOOKSTACK_URL="https://bookstack.example.com"
BOOKSTACK_TOKEN="token_from_bookstack"
PAPERLESS_URL="https://paperless.example.com"
PAPERLESS_TOKEN="token_from_paperless"

# Export for scripts
export BOOKSTACK_URL BOOKSTACK_TOKEN PAPERLESS_URL PAPERLESS_TOKEN

# Navigate to scripts directory
cd "$(dirname "$0")/scripts"

echo "Starting documentation import..."

# Import to both systems
./import-all.sh --both

echo "Documentation imported successfully!"
echo ""
echo "BookStack:  $BOOKSTACK_URL"
echo "Paperless:  $PAPERLESS_URL"
```

### Docker Deployment

To run imports in Docker:

```bash
docker run -v /path/to/stash:/stash ubuntu:latest bash <<EOF
apt-get update
apt-get install -y curl jq pandoc

cd /stash/scripts
export BOOKSTACK_URL=https://bookstack.example.com
export BOOKSTACK_TOKEN=token
./import-bookstack.sh
EOF
```

## Related Documentation

- [BookStack Import Guide](../docs/bookstack/BOOKSTACK_IMPORT.md)
- [1Password Integration](../docs/1password/README.md)
- [Deployment Guide](../DEPLOY_GUIDE.md)
- [Installation and Deployment](../INSTALL_AND_DEPLOY.md)
