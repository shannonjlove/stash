# Oracle Cloud Deployment - Jellyfin & Stash

Complete guide for deploying Jellyfin and Stash on Oracle Cloud with always-on persistence.

## Quick Start (10 minutes)

### Prerequisites
- Oracle Cloud Account (Always Free tier eligible)
- SSH key pair configured
- Basic Linux knowledge

### 1. Create Oracle Compute Instance

```bash
# Via OCI Console:
# 1. Navigate to Compute → Instances
# 2. Click "Create Instance"
# 3. Select Ubuntu 22.04 LTS (Always Free eligible)
# 4. Choose VM.Standard.E2.1.Micro (4GB RAM, 1 CPU - Always Free)
# 5. Configure networking (VCN, subnet, public IP)
# 6. Save SSH key pair
# 7. Click Create

# Note the Public IP address of your instance
```

### 2. SSH into Instance

```bash
# Use the public IP from above
ssh ubuntu@<PUBLIC_IP>

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Deploy Both Services

```bash
# Clone the deployment repo
git clone https://github.com/shannonjlove/stash.git
cd stash/oracle

# Deploy (automated)
./deploy-oracle.sh

# Or deploy individually
./deploy-jellyfin.sh
./deploy-stash.sh
```

### 4. Access Services

```
Jellyfin:  http://<PUBLIC_IP>:8096
Stash:     http://<PUBLIC_IP>:9999
```

## Oracle Cloud Architecture

```
┌─────────────────────────────────────────────┐
│         Oracle Cloud (Always Free)          │
├─────────────────────────────────────────────┤
│  Compute Instance (VM.Standard.E2.1.Micro)  │
│  ├─ 4 GB RAM                                 │
│  ├─ 1 CPU (2 vCPU)                          │
│  └─ 50 GB Boot Volume (Expandable)          │
├─────────────────────────────────────────────┤
│  Docker Services                            │
│  ├─ Jellyfin (Port 8096)                   │
│  │  └─ Media: /media                        │
│  │  └─ Cache: /cache                        │
│  │                                           │
│  └─ Stash (Port 9999)                       │
│     ├─ Config: ~/.stash                     │
│     ├─ Database: SQLite/PostgreSQL          │
│     └─ Storage: /stash-data                 │
├─────────────────────────────────────────────┤
│  Persistent Storage                         │
│  ├─ /home partition (50GB boot volume)      │
│  ├─ Block Storage Volume (optional, 100GB+) │
│  └─ Object Storage (S3-compatible backup)   │
├─────────────────────────────────────────────┤
│  Networking                                 │
│  ├─ Public IP (Ephemeral or Reserved)       │
│  ├─ Security List (Ingress: 80, 443, 8096, 9999) │
│  └─ VCN with auto-assigned DNS              │
└─────────────────────────────────────────────┘
```

## Always-On Configuration

### Systemd Services

Both applications run as systemd services with automatic restart:

```bash
# Check services
systemctl --user status jellyfin
systemctl --user status stash

# View logs
journalctl --user-unit jellyfin -f
journalctl --user-unit stash -f

# Enable auto-start on boot
systemctl --user enable jellyfin
systemctl --user enable stash

# Enable lingering (services persist after logout)
loginctl enable-linger $USER
```

### Docker Compose with Restart Policy

Both services configured with:
```yaml
restart_policy:
  condition: on-failure
  delay: 5s
  max_attempts: 0  # Unlimited retries
  window: 120s
```

This ensures:
- Automatic restart on failure
- Exponential backoff for rapid failures
- Persistent operation across reboots

## Storage Strategy

### Option 1: Boot Volume Only (50GB Always Free)

Suitable for:
- Small media libraries (~500 movies/shows)
- Stash with moderate collection
- Testing and development

**Setup:**
```bash
# Organize in home directory
/home/ubuntu/
├── jellyfin/
│   ├── config/
│   ├── cache/
│   └── media/  (mounted media library)
└── stash/
    ├── data/
    ├── config/
    └── generated/
```

**Estimate:** 50GB can hold ~200 movies + Stash database

### Option 2: Block Storage Volume (Scalable)

Suitable for:
- Large media libraries (1000+ items)
- Long-term storage
- Professional use

**Setup:**
```bash
# Create 100GB+ block storage volume via OCI console
# Attach to instance
# Format and mount:
sudo mkfs.ext4 /dev/sdb1
sudo mkdir -p /mnt/media
sudo mount /dev/sdb1 /mnt/media
sudo chown $USER:$USER /mnt/media

# Add to /etc/fstab for persistence:
echo "UUID=$(blkid -s UUID -o value /dev/sdb1) /mnt/media ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
```

**Cost:** ~$0.05-0.10/GB/month for Always Free block storage

### Option 3: Object Storage Backup (Cost-Effective Archive)

For backup of configurations and metadata:

```bash
# Upload to Oracle Object Storage
# Compress and upload:
tar -czf stash-config.tar.gz ~/.stash/
tar -czf jellyfin-config.tar.gz jellyfin/config/

# Use OCI CLI
oci os object put --bucket-name backups --file stash-config.tar.gz
oci os object put --bucket-name backups --file jellyfin-config.tar.gz
```

## Performance Tuning

### For VM.Standard.E2.1.Micro (Always Free)

**Memory Constraints:**
- Total: 4GB
- System overhead: ~1GB
- Available: ~3GB for containers

**Allocation:**
- Jellyfin: 1.5GB
- Stash: 1GB
- Headroom: 0.5GB

**Enable Swap** (Prevents OOM):
```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
```

### CPU Optimization

The Micro instance has 1 CPU (2 vCPU shared):

```bash
# Limit container CPU usage
# In docker-compose.yml:
services:
  jellyfin:
    cpus: 0.75      # 75% of available
    cpus_reservation: 0.5

  stash:
    cpus: 0.75
    cpus_reservation: 0.5
```

### I/O Optimization

Block storage has limited IOPS (~60-120 IOPS):

```bash
# Mount with performance options
sudo mount -o noatime,async /dev/sdb1 /mnt/media

# Or update fstab:
UUID=xxxxx /mnt/media ext4 noatime,async,errors=remount-ro 0 2
```

## Networking & Security

### Security List Rules

Allow inbound traffic:

```
Stateless:  Yes
Protocol:   TCP
Source:     0.0.0.0/0 (or your IP)
Destination Port:
  - 22   (SSH)
  - 80   (HTTP)
  - 443  (HTTPS - for reverse proxy)
  - 8096 (Jellyfin)
  - 9999 (Stash)
```

### Firewall (UFW)

```bash
# Install and configure
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8096/tcp   # Jellyfin
sudo ufw allow 9999/tcp   # Stash
sudo ufw allow 80/tcp     # HTTP (reverse proxy)
sudo ufw allow 443/tcp    # HTTPS
sudo ufw status
```

### Reverse Proxy (Optional - HTTPS)

Use Nginx for external access:

```bash
# Install Nginx
sudo apt-get install -y nginx

# Create config for Jellyfin
sudo tee /etc/nginx/sites-available/jellyfin << 'EOF'
server {
    listen 80;
    server_name jellyfin.example.com;

    location / {
        proxy_pass http://localhost:8096;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
EOF

# Enable and test
sudo ln -s /etc/nginx/sites-available/jellyfin /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Monitoring & Maintenance

### Health Checks

```bash
# Check both services running
curl -s http://localhost:8096/web/index.html | grep -q "Jellyfin" && echo "Jellyfin OK" || echo "Jellyfin DOWN"
curl -s http://localhost:9999 | grep -q "Stash" && echo "Stash OK" || echo "Stash DOWN"

# Monitor resource usage
docker stats jellyfin stash --no-stream
```

### Backup Strategy

```bash
#!/bin/bash
# backup.sh - Daily backup of configurations

BACKUP_DIR="/mnt/backups"
mkdir -p "$BACKUP_DIR"

# Backup Jellyfin config
tar -czf "$BACKUP_DIR/jellyfin-$(date +%Y%m%d).tar.gz" jellyfin/config/

# Backup Stash config
tar -czf "$BACKUP_DIR/stash-$(date +%Y%m%d).tar.gz" ~/.stash/

# Keep only last 7 days
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

# Upload to Object Storage (optional)
oci os object put --bucket-name backups --file "$BACKUP_DIR"/*.tar.gz
```

**Schedule:**
```bash
# Add to crontab
0 2 * * * /home/ubuntu/backup.sh >> /var/log/backup.log 2>&1
```

### Log Management

```bash
# View application logs
docker compose logs -f jellyfin
docker compose logs -f stash

# Or systemd logs
journalctl --user-unit jellyfin -f
journalctl --user-unit stash -f

# Rotate logs automatically
# Docker handles this with:
# log-driver: json-file
# log-opts:
#   max-size: "10m"
#   max-file: "3"
```

## Cost Estimation

### Always Free Tier (Monthly)

| Resource | Limit | Cost |
|----------|-------|------|
| Compute Instance | 2 micro instances | $0 |
| Memory | 4 GB | $0 |
| Storage (boot) | 50 GB | $0 |
| Data Transfer (out) | 10 GB/month | $0 |
| **Total** | | **$0/month** |

### With Block Storage (Optional)

| Resource | Size | Cost |
|----------|------|------|
| Block Storage | 100 GB | $5/month |
| Block Storage IOPS | 60-120 | $0 (included) |
| **Total** | | **$5/month** |

### Budget Optimization

1. **Always Free:** Use boot volume only (~50GB)
2. **Minimal Cost:** Add 100GB block storage (~$5/month)
3. **Scale-Up:** Add more block storage as needed (~$0.05/GB/month)

## Troubleshooting

### Service Won't Start

```bash
# Check docker status
docker ps
docker logs jellyfin
docker logs stash

# Check systemd status
systemctl --user status jellyfin
journalctl --user-unit jellyfin -n 50

# Restart services
docker compose restart
# or
systemctl --user restart jellyfin stash
```

### Out of Memory

```bash
# Check memory usage
free -h
docker stats

# If OOM:
1. Enable swap (see above)
2. Increase block storage
3. Upgrade instance (no longer Always Free)
4. Reduce media library size
```

### Network Connectivity

```bash
# Test external access
curl -v http://<PUBLIC_IP>:8096/web/index.html
curl -v http://<PUBLIC_IP>:9999

# Check firewall
sudo ufw status
sudo iptables -L -n

# Check security list
# Via OCI Console → VCN → Security Lists
```

### Disk Space Issues

```bash
# Check usage
df -h
du -sh jellyfin/
du -sh stash/
du -sh ~/.stash/

# Clean Docker images
docker image prune -a

# Clean old logs
find . -name "*.log" -mtime +30 -delete
```

## Disaster Recovery

### Restore from Backup

```bash
# Restore Jellyfin
tar -xzf backups/jellyfin-20260725.tar.gz

# Restore Stash
tar -xzf backups/stash-20260725.tar.gz -C ~

# Restart services
docker compose restart
```

### Recreate Instance

1. Detach block storage volume (preserve data)
2. Create new compute instance
3. Install Docker
4. Deploy services
5. Reattach block storage volume
6. Restore from backups

## Security Best Practices

1. **SSH Keys Only** - Disable password authentication
   ```bash
   sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

2. **Firewall Rules** - Restrict access to trusted IPs
   ```bash
   # Only allow specific IP for SSH
   sudo ufw allow from 203.0.113.0 to any port 22
   ```

3. **Regular Updates** - Auto-update security patches
   ```bash
   sudo apt-get install -y unattended-upgrades
   sudo systemctl enable unattended-upgrades
   ```

4. **Secrets Management** - Use environment variables
   ```bash
   # Store sensitive data in .env file
   # Never commit to git
   echo ".env" >> .gitignore
   ```

## Next Steps

1. **Jellyfin Setup**
   - Access http://<IP>:8096
   - Add media libraries
   - Configure transcoding profiles

2. **Stash Setup**
   - Access http://<IP>:9999
   - Complete setup wizard
   - Configure scrapers

3. **Enable HTTPS**
   - Use Let's Encrypt with Nginx
   - Create DNS records pointing to your public IP

4. **External Access**
   - Use Dynamic DNS (if IP changes)
   - Configure reverse proxy with auth
   - Set up VPN for secure access

## References

- [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/)
- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Stash Documentation](https://docs.stashapp.cc/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [OCI Compute Documentation](https://docs.oracle.com/en-us/iaas/compute/using/compute.htm)

---

**Last Updated:** 2026-07-25  
**Version:** 1.0
