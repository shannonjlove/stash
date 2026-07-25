# Oracle Cloud Deployment

Deploy Jellyfin and Stash to Oracle Cloud Always Free tier with always-on persistence.

## Quick Start

### 1. Create Oracle Cloud Instance

```bash
# Via OCI Console (5 minutes)
# Compute → Instances → Create Instance
# - OS: Ubuntu 22.04 LTS
# - Shape: VM.Standard.E2.1.Micro (Always Free)
# - Network: Default VCN
# - Save SSH key
```

### 2. SSH Into Instance

```bash
ssh ubuntu@<PUBLIC_IP>

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Deploy Services

```bash
# Clone and deploy
git clone https://github.com/shannonjlove/stash.git
cd stash/oracle

# Make script executable
chmod +x deploy-oracle.sh

# Run deployment
./deploy-oracle.sh
```

### 4. Access Services

- **Jellyfin:** `http://<PUBLIC_IP>:8096`
- **Stash:** `http://<PUBLIC_IP>:9999`

## Files

- **ORACLE_CLOUD_SETUP.md** - Comprehensive setup guide
- **docker-compose.yml** - Docker Compose configuration
- **deploy-oracle.sh** - Automated deployment script
- **.env.example** - Environment variable template
- **README.md** - This file

## Architecture

```
Oracle Cloud Always Free
├── Compute Instance (VM.Standard.E2.1.Micro)
│   ├── 4 GB RAM
│   ├── 1 CPU (2 vCPU)
│   └── 50 GB Boot Volume
├── Docker Services
│   ├── Jellyfin (Port 8096)
│   └── Stash (Port 9999)
└── Persistent Storage
    ├── Docker Volumes (SQLite, Configs)
    └── Block Storage Volume (Optional, Media)
```

## Always-On Operation

Services are configured to:
- ✓ Auto-restart on failure
- ✓ Start on system reboot
- ✓ Run with unlimited retry attempts
- ✓ Persist across crashes

**Check Status:**
```bash
docker compose ps
docker compose logs -f
systemctl status media-services
```

## Storage Options

### Option 1: Boot Volume Only (Always Free)
- Suitable for: ~500 movies/shows + metadata
- Cost: $0/month
- Setup: Automatic (included in deployment)

### Option 2: Block Storage (Scalable)
- Suitable for: Large media libraries
- Cost: ~$5/month for 100GB
- Setup: Mount and pass path to script

**Mount block storage:**
```bash
# Format volume
sudo mkfs.ext4 /dev/sdb1

# Create mount point
sudo mkdir -p /mnt/media

# Mount
sudo mount /dev/sdb1 /mnt/media

# Make persistent
echo "UUID=$(blkid -s UUID -o value /dev/sdb1) /mnt/media ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Deploy with block storage
./deploy-oracle.sh /mnt/media
```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
# Edit .env with your settings
```

### Docker Compose Customization

Edit `docker-compose.yml` to:
- Adjust resource limits
- Configure media library paths
- Enable PostgreSQL (instead of SQLite)
- Add reverse proxy (Nginx)

### Media Library Paths

**In docker-compose.yml:**
```yaml
volumes:
  # Local media folders
  - /home/ubuntu/jellyfin/movies:/media/movies:ro
  - /home/ubuntu/jellyfin/tv:/media/tv:ro
  
  # Or block storage
  - /mnt/media/jellyfin/movies:/media/movies:ro
  - /mnt/media/stash-content:/stash-content:ro
```

## Management

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f jellyfin
docker compose logs -f stash

# Systemd logs
journalctl --user-unit media-services -f
```

### Stop/Start/Restart

```bash
# Stop all services
docker compose down

# Start all services
docker compose up -d

# Restart
docker compose restart

# Or via systemd
systemctl restart media-services
```

### Update Images

```bash
# Pull latest versions
docker compose pull

# Restart to use new versions
docker compose restart
```

## Performance Tuning

### Memory Management

The Micro instance has 4GB total:
- System: ~1GB
- Available: ~3GB
- Jellyfin: 1.5GB
- Stash: 1GB
- Headroom: 0.5GB

**Enable swap if needed:**
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### CPU Limits

Adjust in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '0.75'      # Use up to 75% CPU
      memory: 1500M
```

### I/O Optimization

Mount block storage with performance options:
```bash
sudo mount -o noatime,async /dev/sdb1 /mnt/media
```

## Monitoring

### Health Checks

```bash
# Check if services are healthy
curl -s http://localhost:8096/web/index.html | grep Jellyfin && echo "Jellyfin OK"
curl -s http://localhost:9999 | grep -q . && echo "Stash OK"
```

### Resource Usage

```bash
# View container stats
docker stats jellyfin stash

# Check disk usage
df -h
du -sh ~/media-services/jellyfin/
du -sh ~/media-services/stash/
```

## Backup Strategy

### Automated Daily Backup

Create `backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p "$BACKUP_DIR"

# Backup configurations
tar -czf "$BACKUP_DIR/jellyfin-$(date +%Y%m%d).tar.gz" ~/media-services/jellyfin/config/
tar -czf "$BACKUP_DIR/stash-$(date +%Y%m%d).tar.gz" ~/.stash/

# Keep only last 7 days
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
```

Schedule with cron:
```bash
# Add to crontab
0 2 * * * /home/ubuntu/backup.sh >> /var/log/backup.log 2>&1
```

## Networking & Security

### Allow Inbound Traffic

In OCI Console → VCN → Security Lists:
```
Protocol: TCP
Source: 0.0.0.0/0
Destination Ports: 22, 80, 443, 8096, 9999
```

### Firewall Rules (UFW)

```bash
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 8096/tcp   # Jellyfin
sudo ufw allow 9999/tcp   # Stash
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
```

### Reverse Proxy (Nginx + HTTPS)

```bash
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Create Nginx config
sudo tee /etc/nginx/sites-available/jellyfin << 'EOF'
server {
    listen 80;
    server_name jellyfin.example.com;
    location / {
        proxy_pass http://localhost:8096;
        proxy_set_header Host $host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable
sudo ln -s /etc/nginx/sites-available/jellyfin /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Enable HTTPS
sudo certbot --nginx -d jellyfin.example.com
```

## Troubleshooting

### Services Won't Start

```bash
# Check Docker
docker ps
docker logs jellyfin

# Check systemd
systemctl status media-services
journalctl -u media-services -n 50

# Restart
docker compose restart
```

### Out of Memory

```bash
# Check memory
free -h
docker stats

# If OOM, enable swap (see above) or upgrade instance
```

### Disk Space Issues

```bash
# Check usage
df -h
du -sh ~/media-services/

# Clean Docker
docker system prune -a
```

### Network Connectivity

```bash
# Test locally
curl http://localhost:8096

# Test from outside
curl http://<PUBLIC_IP>:8096

# Check security list and firewall
sudo ufw status
```

## Cost Estimation

### Always Free (Monthly)

| Item | Cost |
|------|------|
| Compute (2 micro instances) | $0 |
| Storage (50GB boot) | $0 |
| Data transfer (10GB out) | $0 |
| **Total** | **$0** |

### With 100GB Block Storage

| Item | Cost |
|------|------|
| Block Storage | $5 |
| **Total** | **$5/month** |

## Next Steps

1. **Initial Setup**
   - Access Jellyfin at http://IP:8096
   - Add media libraries
   - Access Stash at http://IP:9999
   - Complete setup wizard

2. **Media Library**
   - Upload content to instance
   - Configure library paths
   - Let services scan and index

3. **Remote Access**
   - Configure DNS (optional)
   - Set up reverse proxy with HTTPS
   - Enable in firewall

4. **Monitoring**
   - Set up automated backups
   - Monitor resource usage
   - Keep services updated

## Resources

- [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/)
- [Jellyfin Docs](https://jellyfin.org/docs/)
- [Stash Docs](https://docs.stashapp.cc/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## Support

For issues:
1. Check logs: `docker compose logs -f`
2. Review ORACLE_CLOUD_SETUP.md for detailed troubleshooting
3. Check Docker/service status
4. Verify network and firewall rules

---

**Version:** 1.0  
**Last Updated:** 2026-07-25
