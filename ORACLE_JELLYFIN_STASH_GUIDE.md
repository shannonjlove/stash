# Oracle Cloud + Jellyfin + Stash Guide

Complete guide for deploying Jellyfin and Stash to Oracle Cloud Always Free tier with always-on operation.

## What You're Getting

This deployment gives you:

✓ **Jellyfin** - Open-source media server for movies, TV, music  
✓ **Stash** - Content management system with advanced metadata  
✓ **Oracle Cloud Always Free** - $0/month for compute and storage  
✓ **Always-On** - Services restart on crash or reboot automatically  
✓ **Persistent Storage** - All data persists between reboots  

## Architecture Overview

```
Your Computer
    ↓ (SSH)
Oracle Cloud Public IP
    ↓ (Network)
┌─────────────────────────────┐
│   Oracle VM.Standard.E2.1   │
│   (4GB RAM, 1 CPU, 50GB)   │
├─────────────────────────────┤
│   Jellyfin (Port 8096)      │
│   Stash (Port 9999)         │
├─────────────────────────────┤
│   Docker + Docker Compose   │
├─────────────────────────────┤
│   Ubuntu 22.04 LTS          │
├─────────────────────────────┤
│   Boot Volume (50GB)        │
│   + Optional Block Storage  │
└─────────────────────────────┘
```

## Quick Start (15 Minutes)

### Step 1: Create Oracle Cloud Instance (5 min)

1. Go to [Oracle Cloud Console](https://www.oracle.com/cloud/free/)
2. Click "Sign In"
3. Navigate to **Compute → Instances**
4. Click **Create Instance**
5. Configure:
   - **Image:** Ubuntu 22.04 LTS
   - **Shape:** VM.Standard.E2.1.Micro (Always Free eligible)
   - **Availability Domain:** Any
   - **VCN:** Default
   - **Subnet:** Default Public Subnet
   - **Public IP:** Assign (Ephemeral or Reserved)
   - **SSH Key:** Save your key pair securely
6. Click **Create**

**Note the Public IP address displayed after creation**

### Step 2: Connect and Install Docker (5 min)

```bash
# SSH into your instance
ssh -i /path/to/private/key ubuntu@YOUR_PUBLIC_IP

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Refresh group membership
newgrp docker

# Verify Docker works
docker ps
```

### Step 3: Deploy Services (5 min)

```bash
# Clone repository
git clone https://github.com/shannonjlove/stash.git
cd stash/oracle

# Make script executable
chmod +x deploy-oracle.sh

# Run deployment
./deploy-oracle.sh

# Wait for services to start (30-60 seconds)
docker compose ps

# Check logs
docker compose logs -f
```

### Step 4: Access Services

Open your browser and go to:

**Jellyfin:** `http://YOUR_PUBLIC_IP:8096`  
**Stash:** `http://YOUR_PUBLIC_IP:9999`

## Jellyfin Initial Setup

1. **Language & Region**
   - Select your language
   - Select your region
   - Click "Next"

2. **Add Media Library**
   - Click "Add Media Library"
   - Create library: "Movies"
   - Click folder icon, navigate to `/media/movies`
   - Repeat for TV, Music, etc.
   - Click "Finish"

3. **Metadata Settings**
   - Playback → Streaming
   - Display → Language
   - Library → Metadata

4. **Add Users** (Optional)
   - Administration → Users
   - Create additional user accounts
   - Set permissions

## Stash Initial Setup

1. **Visit Dashboard**
   - http://YOUR_PUBLIC_IP:9999
   - Accept setup wizard

2. **Configure Database**
   - Leave as SQLite (default) for simplicity
   - Or configure PostgreSQL for better performance

3. **Point to Content**
   - Scan for locations
   - Add your content directory
   - Let it scan and index

4. **Configure Scrapers**
   - Settings → Scrapers
   - Enable desired metadata scrapers
   - Configure API keys if needed

5. **Set Preferences**
   - UI Settings
   - Library Organization
   - Playback Settings

## Adding Media

### Option 1: Upload via SFTP

```bash
# On your computer, use SFTP client
# Connect to YOUR_PUBLIC_IP with SSH key
# Upload to: ~/media-services/jellyfin/movies/
# Or: ~/media-services/jellyfin/tv/
# Or: ~/media-services/stash-content/
```

**SFTP Clients:**
- Windows: WinSCP, FileZilla
- macOS: Cyberduck, Transmit
- Linux: Nautilus, Dolphin (built-in SFTP)

### Option 2: Mount Block Storage

For large media libraries (1000+ items):

```bash
# Create block storage via Oracle Console
# Size: 100GB+ (~$5/month)

# On instance, format and mount
sudo mkfs.ext4 /dev/sdb1
sudo mkdir -p /mnt/media
sudo mount /dev/sdb1 /mnt/media
sudo chown ubuntu:ubuntu /mnt/media

# Edit docker-compose.yml to use /mnt/media
# Then restart services
docker compose restart
```

### Option 3: Stream from Network

Configure Jellyfin/Stash to access media from:
- Network shares (NFS, SMB)
- Cloud storage (mounted via rclone)
- External USB drives

## Management Commands

### View Service Status

```bash
# All services
docker compose ps

# Specific service
docker compose ps jellyfin
docker compose ps stash
```

### View Logs

```bash
# All services
docker compose logs -f

# Jellyfin only
docker compose logs -f jellyfin

# Stash only
docker compose logs -f stash

# Last 50 lines
docker compose logs --tail 50 jellyfin
```

### Stop/Start Services

```bash
# Stop all
docker compose down

# Start all
docker compose up -d

# Restart all
docker compose restart

# Restart one service
docker compose restart jellyfin
```

### Update Images

```bash
# Check for updates
docker compose pull

# Apply updates
docker compose restart
```

### Monitor Resources

```bash
# Real-time resource usage
docker stats jellyfin stash

# Disk usage
df -h
du -sh ~/media-services/

# Memory usage
free -h
```

## Persistent Operation

### Auto-Restart on Crash

Configured in `docker-compose.yml`:
```yaml
restart_policy:
  condition: on-failure
  delay: 5s
  max_attempts: 0      # Unlimited retries
  window: 120s
```

Services will restart automatically if they crash.

### Auto-Start on Boot

Configured via systemd:
```bash
# Check status
systemctl status media-services

# Services auto-start via:
sudo systemctl enable media-services

# Manually start if needed
sudo systemctl start media-services
```

### Monitor Systemd Service

```bash
# Status
systemctl status media-services

# Logs
journalctl -u media-services -f

# Recent logs (50 lines)
journalctl -u media-services -n 50
```

## Storage Management

### Available Space

The Always Free instance includes:
- **50GB boot volume** (shared with OS)
- **Actual available:** ~30-40GB for media

This is enough for:
- ~200 movies (500 GB total = 10 movies)
- ~50 TV seasons (150 episodes)
- ~5000 music tracks

### Storage Breakdown

```
50GB Boot Volume
├── OS + System: ~10GB
├── Docker: ~2GB
├── Jellyfin Config: ~500MB
├── Stash Config: ~500MB
├── Media + Libraries: ~30GB
└── Headroom: ~7GB
```

### Add Block Storage

For larger libraries:

1. **Create Volume**
   - Oracle Console → Block Storage → Volumes
   - Size: 100GB+ ($5/month)
   - Attach to instance

2. **Mount Volume**
   ```bash
   sudo mkfs.ext4 /dev/sdb1
   sudo mkdir -p /mnt/media
   sudo mount /dev/sdb1 /mnt/media
   
   # Make permanent
   echo "UUID=$(blkid -s UUID -o value /dev/sdb1) /mnt/media ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
   ```

3. **Use for Media**
   - Store media on `/mnt/media`
   - Configure Jellyfin/Stash to access there

## Networking & Access

### Remote Access

**From anywhere:**
```
http://YOUR_PUBLIC_IP:8096    # Jellyfin
http://YOUR_PUBLIC_IP:9999    # Stash
```

### Local Network Access

If you have a static IP or use VPN:
```bash
# Get instance IP
hostname -I

# Access locally from VPN/network
http://INSTANCE_IP:8096
http://INSTANCE_IP:9999
```

### Custom Domain (Optional)

Use dynamic DNS service:
1. Register domain (or use subdomain)
2. Point to your instance's public IP
3. Use domain instead of IP address

### HTTPS/Reverse Proxy (Optional)

For secure access:
```bash
# Install Nginx
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Install Let's Encrypt certificate
sudo certbot --nginx -d youromain.com

# Configure reverse proxy
# Jellyfin: youromain.com → localhost:8096
# Stash: youromain.com/stash → localhost:9999
```

## Performance & Limits

### Memory

Total: 4GB
- System: ~1GB
- Jellyfin: 1.5GB
- Stash: 1GB
- Headroom: 0.5GB

**Swap file created automatically** for extra 2GB emergency space.

### CPU

Single CPU (2 vCPU shared):
- Can handle ~10 concurrent users
- Transcoding is slower
- Video encoding takes time

### Disk I/O

Limited by network disk:
- Sequential: Good
- Random IOPS: ~60-120
- Consider for database performance

## Backup Strategy

### Automated Backup

Create backup script:

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/home/ubuntu/backups"
mkdir -p "$BACKUP_DIR"

# Backup configurations
tar -czf "$BACKUP_DIR/jellyfin-$(date +%Y%m%d).tar.gz" \
  ~/media-services/jellyfin/config/

tar -czf "$BACKUP_DIR/stash-$(date +%Y%m%d).tar.gz" \
  ~/.stash/

# Keep last 7 days
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
```

Schedule with cron:
```bash
# Edit crontab
crontab -e

# Add line (backup at 2 AM daily)
0 2 * * * /home/ubuntu/backup.sh >> /var/log/backup.log 2>&1
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Restore Jellyfin
tar -xzf backups/jellyfin-20260725.tar.gz

# Restore Stash
tar -xzf backups/stash-20260725.tar.gz -C ~

# Start services
docker compose up -d
```

## Troubleshooting

### Services Won't Start

```bash
# Check Docker
docker ps
docker compose ps

# View logs
docker compose logs -f

# Restart
docker compose restart

# Check systemd
systemctl status media-services
journalctl -u media-services -n 50
```

### Out of Memory (OOM)

```bash
# Check memory
free -h
docker stats

# Solutions:
# 1. Swap is automatic (already created)
# 2. Stop unnecessary services
# 3. Upgrade instance (no longer Free)
# 4. Add block storage
```

### Disk Full

```bash
# Check usage
df -h

# Find large files
du -sh ~/media-services/

# Clean up
# Remove old backups
rm -rf ~/backups/old/*

# Clean Docker
docker system prune -a

# Remove media if necessary
```

### Network Issues

```bash
# Test local access
curl http://localhost:8096
curl http://localhost:9999

# Test remote access
curl http://YOUR_PUBLIC_IP:8096

# Check firewall
sudo ufw status

# Check security list
# Oracle Console → VCN → Security Lists
```

## Cost Analysis

### Monthly Cost

**Always Free Tier:**
- Compute: $0
- Storage (50GB): $0
- Data Transfer (10GB/month out): $0
- **Total: $0/month**

**With 100GB Block Storage:**
- Block Storage: ~$5/month
- **Total: ~$5/month**

### Annual Cost

- Always Free: $0/year
- With Block Storage: $60/year

### Comparison to Alternatives

| Provider | CPU | RAM | Storage | Cost/Month |
|----------|-----|-----|---------|-----------|
| Oracle Always Free | 1 | 4GB | 50GB | $0 |
| Oracle with Block | 1 | 4GB | 150GB | $5 |
| Linode Nanode | 1 | 1GB | 25GB | $5 |
| DigitalOcean | 1 | 1GB | 25GB | $6 |
| AWS EC2 (always on) | - | - | - | $15-50 |

**Oracle Always Free is unbeatable for this use case.**

## Migration & Scale-Up

### From Local to Oracle

1. Back up Jellyfin config
2. Back up Stash database
3. Deploy to Oracle
4. Restore configurations
5. Re-index media libraries

### Upgrade Instance

If Always Free limits aren't enough:

```bash
# Via Oracle Console
# Compute → Instances → Instance Details
# Click "Change Shape"
# Choose larger shape (costs money)
```

### Add Database

For better Stash performance:

```bash
# Uncomment PostgreSQL in docker-compose.yml
# Set environment variables
# Restart services
docker compose restart
```

## Security Considerations

### SSH Security

```bash
# Disable password auth (key-only)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### Firewall Rules

In Oracle Console → VCN → Security Lists:
```
- Source: 0.0.0.0/0 (or restrict to your IP)
- TCP Port 22 (SSH)
- TCP Port 8096 (Jellyfin)
- TCP Port 9999 (Stash)
```

### Regular Updates

```bash
# Enable automatic security updates
sudo apt-get install -y unattended-upgrades
sudo systemctl enable unattended-upgrades
```

## References

- [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/)
- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Stash Documentation](https://docs.stashapp.cc/)
- [Docker Compose](https://docs.docker.com/compose/)
- [OCI Documentation](https://docs.oracle.com/en-us/iaas/)

## Next Steps

1. ✓ Create Oracle instance
2. ✓ Deploy Jellyfin & Stash
3. Add media library
4. Configure streaming settings
5. Invite users
6. Set up remote access (optional)
7. Configure HTTPS (optional)

---

**Version:** 1.0  
**Last Updated:** 2026-07-25

**Support:**
- Check logs: `docker compose logs -f`
- Review ORACLE_CLOUD_SETUP.md for detailed guide
- Check Jellyfin/Stash official docs
