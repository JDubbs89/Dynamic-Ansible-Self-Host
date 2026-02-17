# Quick Reference

## Common Commands

### Deploy Everything
```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

### Deploy Specific Service
```bash
ansible-playbook -i inventory/hosts.yml site.yml --tags=matrix
ansible-playbook -i inventory/hosts.yml site.yml --tags=pelican
ansible-playbook -i inventory/hosts.yml site.yml --tags=traefik
```

### Check What Would Change (Dry Run)
```bash
ansible-playbook -i inventory/hosts.yml site.yml --check --diff
```

### Run Only on Specific Host
```bash
ansible-playbook -i inventory/hosts.yml site.yml --limit homelab
```

## Service Management

### Restart Services
```bash
# Traefik
cd /opt/homelab/traefik && docker compose restart

# Pelican
cd /opt/homelab/pelican && docker compose restart

# Matrix (from MDAD directory)
cd /opt/homelab/matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts setup.yml --tags=start
```

### View Logs
```bash
# All services
docker ps
docker logs <container_name>

# Specific services
docker logs traefik
docker logs pelican_panel
docker logs pelican_wings
docker logs matrix-synapse
```

### Check Service Status
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Matrix Commands

### Create Matrix User
```bash
cd /opt/homelab/matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts setup.yml \
  --tags=register-user \
  --extra-vars='username=USERNAME password=PASSWORD admin=yes'
```

### Update Matrix
```bash
cd /opt/homelab/matrix-docker-ansible-deploy
git pull
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

## Tailscale Commands

### Check Status
```bash
tailscale status
```

### Get IP Address
```bash
tailscale ip -4
```

### Disconnect/Reconnect
```bash
tailscale down
tailscale up
```

## Pelican Commands

### Rebuild Images (New Version)
```bash
# Update versions in group_vars/all.yml first
ansible-playbook -i inventory/hosts.yml site.yml --tags=pelican

# Or manually
cd /opt/homelab/pelican
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Wings Config
```bash
# Edit Wings config
sudo nano /etc/pelican/config.yml

# Restart after editing
cd /opt/homelab/pelican && docker compose restart wings
```

## Troubleshooting

### Check All Containers
```bash
docker ps -a
```

### Check Networks
```bash
docker network ls
docker network inspect traefik
```

### Check Disk Usage
```bash
df -h
docker system df
```

### Clean Up Docker
```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Nuclear option (be careful!)
docker system prune -a --volumes
```

### Check Firewall
```bash
# Check iptables rules
sudo iptables -L -n

# Check what's listening
sudo ss -tlnp
```

### Oracle Cloud Firewall Fix
```bash
sudo iptables -F
sudo netfilter-persistent save
```

## File Locations

| Service | Location |
|---------|----------|
| Traefik | `/opt/homelab/traefik` |
| Matrix | `/opt/homelab/matrix-docker-ansible-deploy` |
| Pelican | `/opt/homelab/pelican` |
| Wings Config | `/etc/pelican/config.yml` |
| Wings Data | `/var/lib/pelican/volumes` |

## Ports Reference

| Port | Service | Public? |
|------|---------|---------|
| 22 | SSH | ✓ |
| 80 | Traefik HTTP | ✓ (VPN-only via Traefik) |
| 443 | Traefik HTTPS | ✓ (VPN-only via Traefik) |
| 2022 | Wings SFTP | ✓ (VPN-only) |
| 8443 | Wings API | ✓ (VPN-only via Traefik) |
| 25565 | Minecraft | ✓ |

## DNS Records Needed

```
matrix.yourdomain.com   → YOUR_SERVER_IP
element.yourdomain.com  → YOUR_SERVER_IP
panel.yourdomain.com    → YOUR_SERVER_IP
wings.yourdomain.com    → YOUR_SERVER_IP
```

## Access URLs (via Tailscale)

- Matrix: `https://matrix.yourdomain.com`
- Element: `https://element.yourdomain.com`
- Pelican Panel: `https://panel.yourdomain.com`
- Wings API: `https://wings.yourdomain.com`
- Traefik Dashboard: `https://traefik.yourdomain.com`

## Backup Important Files

```bash
# On server, create backup
tar -czf backup-$(date +%Y%m%d).tar.gz \
  /opt/homelab \
  /etc/pelican \
  /var/lib/pelican

# Copy to local machine
scp ubuntu@YOUR_SERVER_IP:backup-*.tar.gz .
```
