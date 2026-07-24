# Adding Stash Deployment Docs to BookStack

This guide explains how to import the Stash deployment documentation into BookStack.

## Quick Import

### Option 1: Manual Copy-Paste

1. In BookStack, create a new shelf named "Stash"
2. Create books for each section:
   - Installation & Deployment
   - Docker Setup
   - Podman Setup
   - Advanced Configuration

3. Copy content from these files into BookStack pages:
   - `INSTALL_AND_DEPLOY.md` → Installation Book
   - `QUICK_START_DEPLOYMENT.md` → Quick Start Page
   - `DEPLOYMENT_COMPARISON.md` → Comparison Page
   - `podman/QUADLET_SETUP.md` → Podman Book
   - `podman/QUADLET_QUICK_START.md` → Podman Quick Start
   - `podman/TEMPLATE_USAGE.md` → Templates Page

### Option 2: HTML Export

Convert markdown files to HTML and import:

```bash
# Install pandoc (if not already installed)
sudo apt install pandoc

# Convert markdown to HTML
pandoc INSTALL_AND_DEPLOY.md -o INSTALL_AND_DEPLOY.html
pandoc podman/QUADLET_SETUP.md -o QUADLET_SETUP.html
pandoc DEPLOYMENT_COMPARISON.md -o DEPLOYMENT_COMPARISON.html
```

Then import HTML files into BookStack.

### Option 3: JSON for BookStack API

Use BookStack's REST API to import content programmatically:

```bash
# Create a book
curl -X POST http://your-bookstack/api/books \
  -H "Authorization: Token <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Stash Deployment",
    "description": "Complete guide for installing and deploying Stash"
  }'

# Create chapters and pages
curl -X POST http://your-bookstack/api/chapters \
  -H "Authorization: Token <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Installation",
    "book_id": <book_id>,
    "description": "Installation guides for all platforms"
  }'
```

## BookStack Directory Structure

Organize as follows:

```
Shelf: Stash Documentation
├── Book: Getting Started
│   ├── Chapter: Installation
│   │   ├── Page: System Requirements
│   │   ├── Page: Quick Start
│   │   └── Page: Docker Setup
│   ├── Chapter: Deployment Methods
│   │   ├── Page: Comparison
│   │   ├── Page: Docker Compose
│   │   └── Page: Podman Quadlet
│   └── Chapter: First Run
│       ├── Page: Initial Setup
│       └── Page: Configuration
├── Book: Podman Quadlet
│   ├── Chapter: User Service
│   │   ├── Page: Quick Start
│   │   └── Page: Setup Guide
│   ├── Chapter: System Service
│   │   ├── Page: Installation
│   │   └── Page: Management
│   ├── Chapter: Templates
│   │   ├── Page: Template System
│   │   ├── Page: Multiple Instances
│   │   └── Page: Custom Configs
│   └── Chapter: Troubleshooting
│       ├── Page: Common Issues
│       └── Page: Performance Tuning
├── Book: Docker Deployment
│   ├── Chapter: Quick Start
│   │   ├── Page: Setup
│   │   └── Page: First Run
│   ├── Chapter: Configuration
│   │   ├── Page: Environment
│   │   └── Page: Customization
│   └── Chapter: Management
│       ├── Page: Commands
│       └── Page: Maintenance
└── Book: Advanced Topics
    ├── Chapter: Reverse Proxy
    ├── Chapter: Backup & Restore
    ├── Chapter: Performance Tuning
    └── Chapter: Security
```

## Content Mapping

### Book 1: Getting Started

**Chapter: Installation**
- Copy from: `INSTALL_AND_DEPLOY.md` (sections: Prerequisites, Deployment Options)

**Chapter: Deployment Methods**
- Copy from: `DEPLOYMENT_COMPARISON.md`

**Chapter: First Run**
- Copy from: `INSTALL_AND_DEPLOY.md` (First Run Setup section)

### Book 2: Podman Quadlet

**Chapter: Quick Start**
- Copy from: `podman/QUADLET_QUICK_START.md`

**Chapter: Setup**
- Copy from: `podman/QUADLET_SETUP.md` (Installation section)

**Chapter: Management**
- Copy from: `podman/QUADLET_SETUP.md` (Service Management section)

**Chapter: Templates**
- Copy from: `podman/TEMPLATE_USAGE.md`

**Chapter: Troubleshooting**
- Copy from: `podman/QUADLET_SETUP.md` (Troubleshooting section)

### Book 3: Docker Deployment

**Chapter: Quick Start**
- Copy from: `QUICK_START_DEPLOYMENT.md`

**Chapter: Configuration**
- Copy from: `INSTALL_AND_DEPLOY.md` (Docker Deployment and Configuration sections)

**Chapter: Management**
- Copy from: `INSTALL_AND_DEPLOY.md` (Docker Maintenance section)

## BookStack Features to Use

### Callout Blocks

Use BookStack's callout feature for important notes:

```
⚠️ **Warning**: Don't run as root unnecessarily

ℹ️ **Tip**: Use tags to organize your documentation

✓ **Success**: Service started successfully
```

### Code Blocks

BookStack supports syntax highlighting:

```bash
# This will be highlighted as bash
docker compose up -d
```

```yaml
# YAML highlighting
version: '3'
services:
  stash:
    image: stashapp/stash:latest
```

### Tables

Use markdown tables which BookStack renders nicely:

| Feature | Docker | Podman |
|---------|--------|--------|
| Setup Time | 3 min | 2 min |
| Overhead | 150MB | 20MB |

### Internal Links

Use BookStack's link feature to cross-reference pages:

- [See Podman Setup](#) 
- [Check Docker Configuration](#)
- [Review Templates](#)

## Import via Markdown

BookStack can import markdown files directly:

1. Go to Settings → Content → Export
2. Create markdown files with proper frontmatter:

```markdown
---
title: Stash Installation Guide
description: Complete guide for installing Stash
tags: stash, installation, deployment
---

# Installation Guide

Content here...
```

3. Use BookStack's API or web interface to import

## Create a BookStack Page Template

For consistency, create a template for Stash documentation pages:

**Page Template:**
```markdown
# [Topic Name]

## Overview
[Brief description]

## Prerequisites
- [Requirement 1]
- [Requirement 2]

## Installation/Setup
### Step 1: [Step Name]
[Instructions]

### Step 2: [Step Name]
[Instructions]

## Configuration
### Option 1: [Configuration]
[Details]

### Option 2: [Configuration]
[Details]

## Verification
```bash
[Commands to verify]
```

## Troubleshooting
### Issue: [Problem]
**Solution**: [Solution]

## See Also
- [Related Page 1](#)
- [Related Page 2](#)

## References
- [External Link 1](url)
- [External Link 2](url)
```

## Maintenance

### Keep Documentation Updated

1. When Stash is updated, update BookStack
2. Use version numbers in page titles
3. Archive old versions in a separate shelf

### Monitor Links

BookStack can check for broken links. Set up periodic reviews:
- Settings → Maintenance → Link Checking

### User Permissions

Set appropriate permissions:
- Admins: Full access
- Viewers: Read-only
- Editors: Can edit/create pages

## Export Back to GitHub

To sync BookStack back to your repository:

```bash
# Export from BookStack API
curl -X GET http://your-bookstack/api/books/<book_id> \
  -H "Authorization: Token <token>" \
  -H "Accept: application/json" > stash-book.json

# Convert to markdown
# (Use a conversion tool or script)
```

## Best Practices

1. **Keep it organized**: Use consistent chapter/page structure
2. **Use tags**: Tag all Stash pages with "stash" for easy finding
3. **Link internally**: Reference related pages within BookStack
4. **Add images**: Include screenshots of setup process
5. **Version control**: Note which Stash version documentation applies to
6. **Update dates**: Add "Last Updated" to each page
7. **Assign owners**: Set up page watchers for documentation sections

## Creating a Searchable Knowledge Base

BookStack's built-in search works best when:
- Pages have descriptive titles
- Content uses proper headings (H2, H3)
- Tags are applied consistently
- Internal links are used

Example tags for Stash:
- `stash`
- `stash-deployment`
- `docker`
- `podman`
- `quick-start`
- `troubleshooting`
- `advanced`

## Automating Updates

Create a script to sync documentation:

```bash
#!/bin/bash
# sync-bookstack.sh - Sync markdown files to BookStack

BOOKSTACK_URL="http://your-bookstack"
BOOKSTACK_TOKEN="your-api-token"
BOOK_ID=1

# Upload each markdown file
for file in *.md podman/*.md; do
    # Convert to HTML
    pandoc "$file" -o "${file%.md}.html"
    
    # Upload via API
    curl -X POST "$BOOKSTACK_URL/api/pages" \
        -H "Authorization: Token $BOOKSTACK_TOKEN" \
        -F "file=@${file%.md}.html"
done
```

---

**Tips for Success:**
1. Start with Quick Start pages
2. Build out detailed guides
3. Add examples as you go
4. Use media (screenshots, videos)
5. Get user feedback
6. Keep searching the docs
7. Update regularly

**BookStack Resources:**
- [Official Documentation](https://www.bookstackapp.com/)
- [API Documentation](https://demo.bookstackapp.com/api/docs)
- [Community](https://community.bookstackapp.com/)
