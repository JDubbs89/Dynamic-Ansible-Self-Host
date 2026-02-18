# Setup Guide

This guide walks you through deploying the entire self-hosted stack from scratch.

## Prerequisites

### On Your Local Machine

1. **Ansible installed** (version 2.14+):
   ```bash
   # macOS
   brew install ansible
   
   # Ubuntu/Debian
   sudo apt update && sudo apt install ansible
   
   # Verify
   ansible --version
   ```

2. **SSH key for your server**:
   ```bash
   # Generate if you don't have one
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

### On Your Server (Oracle Cloud)

1. **Ubuntu 24.04 LTS** instance provisioned
2. **Firewall rules** configured in Oracle Cloud Console:

   Navigate to: **Networking → Virtual Cloud Networks → Your VCN → Security Lists → Default Security List**
   
   Add these **Ingress Rules**:
   
   | Source | Protocol | Port Range | Description |
   |--------|----------|------------|-------------|
   | 0.0.0.0/0 | TCP | 22 | SSH |
   | 0.0.0.0/0 | TCP | 80 | HTTP (ACME challenges) |
   | 0.0.0.0/0 | TCP | 443 | HTTPS |
   | 0.0.0.0/0 | TCP | 25565 | Minecraft (default) |
   | 0.0.0.0/0 | TCP + UDP | 25565 | Minecraft |

3. **DNS records** pointing to your server's public IP:
   
   | Record Type | Name | Value |
   |-------------|------|-------|
   | A | matrix | YOUR_SERVER_IP |
   | A | element | YOUR_SERVER_IP |
   | A | panel | YOUR_SERVER_IP |
   | A | wings | YOUR_SERVER_IP |

## Step 1: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/yourusername/dynamic-ansible-self-host.git
cd dynamic-ansible-self-host

# Install Ansible dependencies
ansible-galaxy collection install -r requirements.yml
```

## Step 2: Configure Your Variables

### Using Environment Variables (Recommended for Security)

**IMPORTANT**: All sensitive information should be stored in environment variables, NOT in the configuration files that will be committed to git.

1. **Copy the example environment file**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your actual values**:
   ```bash
   # Core Infrastructure
   ANSIBLE_HOST=your.server.ip.address
   BASE_DOMAIN=yourdomain.com
   LETSENCRYPT_EMAIL=your@example.com
   TIMEZONE=America/New_York
   
   # Tailscale (get from https://login.tailscale.com/admin/settings/keys)
   TAILSCALE_AUTH_KEY=tskey-YOUR_KEY_HERE
   
   # Matrix-specific
   MATRIX_HOMESERVER_GENERIC_SECRET_KEY=<generate-a-random-secret>
   POSTGRES_CONNECTION_PASSWORD=<generate-a-strong-password>
   
   # SSH/Ansible
   ANSIBLE_USER=ubuntu
   ANSIBLE_SSH_PRIVATE_KEY_FILE=/root/.ssh/your-key.key
   ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3
   ```

3. **Load environment variables before running Ansible**:
   ```bash
   # On Linux/macOS
   source .env
   
   # On Windows PowerShell
   Get-Content .env | ForEach-Object {
       $name, $value = $_.Split("=")
       [Environment]::SetEnvironmentVariable($name, $value)
   }
   ```

4. **Verify .env is in .gitignore**:
   ```bash
   # Check if .env is already listed
   grep '\.env' .gitignore
   
   # You should see:
   # .env
   # .env.local
   # .env.*.local
   # .env.production.local
   ```

### Alternative: Direct Configuration (Less Secure)

If you prefer not to use environment variables, edit the files directly:

Edit `group_vars/all.yml`:

```yaml
base_domain: "yourdomain.com"              # Your actual domain
letsencrypt_email: "you@example.com"       # Your email
timezone: "America/New_York"               # Your timezone

# Optional: Tailscale auth key for non-interactive setup
# Get from: https://login.tailscale.com/admin/settings/keys
tailscale_auth_key: ""
```

Edit `inventory/hosts.yml`:

```yaml
all:
  hosts:
    homelab:
      ansible_host: YOUR_SERVER_PUBLIC_IP
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_rsa  # Path to your SSH key
```

### Manual Configuration (Old Method)

Edit `group_vars/all.yml`:

```yaml
base_domain: "yourdomain.com"              # Your actual domain
letsencrypt_email: "you@example.com"       # Your email
timezone: "America/New_York"               # Your timezone

# Optional: Tailscale auth key for non-interactive setup
# Get from: https://login.tailscale.com/admin/settings/keys
tailscale_auth_key: ""
```

Edit `inventory/hosts.yml`:

```yaml
all:
  hosts:
    homelab:
      ansible_host: YOUR_SERVER_PUBLIC_IP
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_rsa  # Path to your SSH key
```

## Step 3: Test Connectivity

```bash
# Test SSH connection
ansible all -i inventory/hosts.yml -m ping

# Expected output:
# homelab | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

## Step 4: Run the Playbook

### Full Deployment (recommended first run)

```bash
ansible-playbook -i inventory/hosts.yml site.yml
```

This will take 15-30 minutes depending on your server's specs.

### Deploy Individual Services

```bash
# Just the base system + Tailscale
ansible-playbook -i inventory/hosts.yml site.yml --tags base,tailscale

# Just Matrix
ansible-playbook -i inventory/hosts.yml site.yml --tags matrix

# Just Pelican
ansible-playbook -i inventory/hosts.yml site.yml --tags pelican
```

## Step 5: Tailscale Setup

If you didn't provide an auth key in `group_vars/all.yml`:

```bash
# SSH into your server
ssh ubuntu@YOUR_SERVER_IP

# Authenticate Tailscale
sudo tailscale up

# Visit the displayed URL in your browser to authenticate
```

On your local machine:

```bash
# Install Tailscale
# macOS: brew install tailscale
# Linux: curl -fsSL https://tailscale.com/install.sh | sh

# Connect
tailscale up

# Get your server's Tailscale IP
ssh ubuntu@YOUR_SERVER_IP "tailscale ip -4"
```

## Step 6: Access Your Services

### Via Tailscale (required for admin interfaces)

Install the Tailscale app on your device and connect to your network.

Then access:
- **Element Web**: `https://element.yourdomain.com`
- **Pelican Panel**: `https://panel.yourdomain.com/installer`
- **Traefik Dashboard**: `https://traefik.yourdomain.com`

### Publicly Accessible (no VPN)

- **Minecraft**: `your-server-ip:25565` (after you create a server in Pelican)

## Step 7: Complete Pelican Setup

1. Visit `https://panel.yourdomain.com/installer`
2. Complete the installation wizard:
   - **Server Requirements**: Should all be green
   - **Environment**: Your email and create admin credentials
   - **Database**: Accept defaults (MySQL)
   - **Cache**: Accept defaults (Redis)
   - **Queue**: Accept defaults (Redis)
   - **Session**: Accept defaults (File)

3. Create a Node:
   - Go to **Nodes** → **Create Node**
   - **Domain Name**: `wings.yourdomain.com`
   - **Advanced Settings**: Set memory/disk limits
   - Click **Create Node**

4. Configure Wings:
   - Copy the generated `config.yml` from the Panel UI
   - SSH into your server:
     ```bash
     sudo nano /etc/pelican/config.yml
     # Paste the config
     ```
   - **CRITICAL**: Find `ssl:` section and set:
     ```yaml
     ssl:
       enabled: false
     ```
   - Add the Docker network config to the end of the file:
     ```yaml
     docker:
       network:
         interface: 172.50.0.1
         dns:
           - 192.168.1.1  # Your server's DNS (or 8.8.8.8)
           - 1.0.0.1
         name: wings1
         ispn: false
         driver: bridge
         network_mode: wings1
         is_internal: false
         enable_icc: true
         network_mtu: 1500
         interfaces:
           v4:
             subnet: 172.50.0.0/16
             gateway: 172.50.0.1
           v6:
             subnet: fdba:17c8:6c94::/64
             gateway: fdba:17c8:6c94::1011
       allowed_mounts: []
       allowed_origins: []
       allow_cors_private_network: false
       ignore_panel_config_updates: false
     ```
   - Save and restart Wings:
     ```bash
     cd /opt/homelab/pelican
     docker compose restart wings
     ```

5. Verify Node Health:
   - Return to Panel → **Nodes**
   - You should see a green heart under "Health"

## Step 8: Complete Matrix Setup

1. SSH into your server
2. Create your first Matrix user:
   ```bash
   cd /opt/homelab/matrix-docker-ansible-deploy
   
   # Create an admin user
   ansible-playbook -i inventory/hosts setup.yml \
     --tags=register-user \
     --extra-vars='username=YOUR_USERNAME password=YOUR_PASSWORD admin=yes'
   ```

3. Access Element:
   - Visit `https://element.yourdomain.com`
   - Click "Sign In"
   - **Homeserver**: `https://matrix.yourdomain.com`
   - Use your credentials from step 2

## Step 9: Create Your First Minecraft Server

1. In Pelican Panel, go to **Nodes** → **wings1** → **Allocations**
2. Click **Create Allocations**:
   - IP: `0.0.0.0`
   - Ports: `25565-25570`
   - Submit

3. Go to **Servers** → **Create New**
4. Fill in details:
   - **Server Name**: "Minecraft Server"
   - **Node**: wings1
   - **Allocation**: Select 25565
   - **Egg**: Vanilla Minecraft
   - **Server Version**: (leave default or specify, e.g. "1.21.1")
   - **Memory**: 2048 MB (adjust as needed)
   - **Disk**: 5000 MB

5. Click **Create Server**
6. Go to **Console** and click **Start**

7. Connect from Minecraft:
   - Server Address: `your-server-ip:25565`

## Troubleshooting

### Traefik Not Generating Certificates

```bash
# Check Traefik logs
docker logs traefik

# Verify DNS is working
dig panel.yourdomain.com

# Ensure port 80 is open for ACME HTTP challenge
sudo iptables -L -n | grep 80
```

### Wings Shows No Green Heart

```bash
# Check Wings logs
docker logs pelican_wings

# Verify config exists and ssl.enabled is false
cat /etc/pelican/config.yml | grep -A 2 "ssl:"

# Restart Wings
cd /opt/homelab/pelican && docker compose restart wings
```

### Can't Access Services (ERR_CONNECTION_REFUSED)

```bash
# Verify you're connected to Tailscale
tailscale status

# Check if services are running
docker ps

# Verify Traefik network
docker network inspect traefik
```

### Oracle Cloud Firewall Issues

```bash
# Flush iptables (base role should do this, but if not)
sudo iptables -F
sudo netfilter-persistent save

# Check what's listening
sudo ss -tlnp | grep -E ":(80|443|25565)"
```

## Next Steps

- **Add more game servers**: Use Pelican Panel's server creation
- **Invite friends to Matrix**: Create users with the register-user command
- **Add more services**: Create new roles following the pattern in `roles/pelican`
- **Backup**: Consider backing up `/opt/homelab` and `/etc/pelican`

## Updating

```bash
# Update all services
ansible-playbook -i inventory/hosts.yml site.yml

# Update just Matrix
cd /opt/homelab/matrix-docker-ansible-deploy
git pull
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start

# Rebuild Pelican images (when new version released)
cd /opt/homelab/pelican
docker compose down
# Update version in group_vars/all.yml
ansible-playbook -i inventory/hosts.yml site.yml --tags=pelican
```
