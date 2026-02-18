# Environment Variables Configuration Guide

This document explains all the environment variables used in the Dynamic Ansible Self-Host project and how to obtain/generate them.

## Quick Start

```bash
# Copy the example file
cp .env.example .env

# Edit with your values
nano .env  # or your preferred editor

# Load environment variables (do this before running Ansible)
source .env  # Linux/macOS
# or
Get-Content .env | ForEach-Object { [Environment]::SetEnvironmentVariable($_.Split("=")[0], $_.Split("=")[1]) }  # PowerShell
```

## Critical Security Notes

⚠️ **NEVER commit `.env` to version control**
- The `.gitignore` file already excludes `.env*` pattern
- Always use `.env.example` to document what variables are needed
- Create `.env` locally with actual values

## Environment Variables Reference

### Core Infrastructure

#### `ANSIBLE_HOST`
- **What it is**: The IP address or hostname of your server
- **Example**: `147.224.210.58`
- **How to obtain**: Your Oracle Cloud, AWS, or VPS provider dashboard
- **Required**: ✅ Yes

#### `BASE_DOMAIN`
- **What it is**: Your primary domain name (all services will use subdomains)
- **Example**: `yourdomain.com`
- **How to obtain**: Register with a domain registrar (GoDaddy, Namecheap, Route53, etc.)
- **Required**: ✅ Yes

#### `LETSENCRYPT_EMAIL`
- **What it is**: Email for Let's Encrypt SSL certificate notifications
- **Example**: `your@example.com`
- **How to obtain**: Any email address you check regularly
- **Required**: ✅ Yes
- **Note**: Let's Encrypt will send renewal reminders to this email

#### `TIMEZONE`
- **What it is**: Server timezone for timestamps and scheduling
- **Example**: `America/New_York`, `Europe/London`, `Asia/Tokyo`
- **How to obtain**: Run `timedatectl list-timezones` to see all available timezones
- **Required**: ✅ Yes

### Tailscale Configuration

#### `TAILSCALE_AUTH_KEY`
- **What it is**: Authentication key for non-interactive Tailscale setup
- **Example**: `tskey-XXXXXXXXXXXXX`
- **How to obtain**:
  1. Go to https://login.tailscale.com/admin/settings/keys
  2. Click "Create auth key"
  3. Choose:
     - **Reusable**: ✓ (so you can use it multiple times)
     - **Expiration**: Set to your preference (30 days or longer)
     - **Pre-auth key**: Optional, auto-asserts device
  4. Copy the token and paste it here
- **Required**: ❌ No (leave empty to use interactive auth)
- **Note**: Without this, you'll need to manually authenticate with `sudo tailscale up` on the server

### Matrix (Synapse) Configuration

#### `MATRIX_ADMIN_EMAIL`
- **What it is**: Admin contact email for your Matrix server
- **Example**: `admin@yourdomain.com`
- **Required**: ✅ Yes

#### `MATRIX_DOMAIN`
- **What it is**: The domain where Matrix Synapse will be accessible
- **Example**: `matrix.yourdomain.com`
- **Required**: ✅ Yes

#### `ELEMENT_DOMAIN`
- **What it is**: The domain where Element Web client will be accessible
- **Example**: `element.yourdomain.com`
- **Required**: ✅ Yes

#### `MATRIX_HOMESERVER_GENERIC_SECRET_KEY`
- **What it is**: A secret key used by Synapse for encryption and security
- **How to generate**:
  ```bash
  python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + string.punctuation) for _ in range(128)))"
  ```
  Or:
  ```bash
  openssl rand -base64 128
  ```
- **Required**: ✅ Yes
- **Note**: Must be cryptographically random and kept secret

#### `POSTGRES_CONNECTION_PASSWORD`
- **What it is**: Password for Matrix database (PostgreSQL)
- **How to generate**:
  ```bash
  python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32)))"
  ```
- **Required**: ❌ No (will auto-generate if not provided)
- **Note**: Only set if you want a specific password; otherwise Ansible will auto-generate

### Matrix Bot Configuration

#### `MATRIX_BOT_MJOLNIR_ACCESS_TOKEN`
- **What it is**: Access token for the Mjolnir moderation bot
- **How to obtain**: Auto-generated on first run, then retrieve from the bot's config
- **Required**: ❌ No (will be auto-generated)
- **Note**: Used for managing moderation rules, bans, and room protection

#### `MATRIX_BOT_HONOROIT_PASSWORD`
- **What it is**: Password for the Honoroit help desk bot account
- **How to generate**:
  ```bash
  python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(24)))"
  ```
- **Required**: ❌ No
- **Note**: Only needed if you enable Honoroit bot

#### `MATRIX_BOT_HONOROIT_ROOMID`
- **What it is**: Matrix room ID where Honoroit help desk tickets will be sent
- **Example**: `!abc123def456:yourdomain.com`
- **How to obtain**: Create a room in Element, then check room settings for the ID
- **Required**: ❌ No

#### `MATRIX_MAUTRIX_DISCORD_TOKEN`
- **What it is**: Discord bot token for the Matrix-Discord bridge
- **How to obtain**:
  1. Go to https://discord.com/developers/applications
  2. Click "New Application" and name it
  3. Go to "Bot" tab → "Add Bot"
  4. Copy the **Token** (click "Copy" button)
  5. Do NOT share this token
- **Required**: ❌ No (only if using Discord bridge)
- **Note**: Keep this secret - it gives full access to your Discord bot

#### `MATRIX_MAUTRIX_DISCORD_BOT_ID`
- **What it is**: The numeric ID of your Discord bot application
- **How to obtain**: 
  1. In Discord Developer Portal, go to "General Information"
  2. Copy the **Application ID**
- **Required**: ❌ No

### Pelican (Game Panel) Configuration

#### `PELICAN_PANEL_DOMAIN`
- **What it is**: Domain where Pelican Panel admin interface will be accessible
- **Example**: `panel.yourdomain.com`
- **Required**: ✅ Yes

#### `PELICAN_WINGS_DOMAIN`
- **What it is**: Domain where Wings game server API will be accessible
- **Example**: `wings.yourdomain.com`
- **Required**: ✅ Yes

#### `PELICAN_ADMIN_EMAIL`
- **What it is**: Administrator email for Pelican Panel
- **Example**: `admin@yourdomain.com`
- **Required**: ✅ Yes

### SSH/Ansible Configuration

#### `ANSIBLE_USER`
- **What it is**: SSH username on your server
- **Example**: `ubuntu`, `ec2-user`, `root`
- **Default**: `ubuntu` (for Ubuntu 24.04)
- **Required**: ✅ Yes

#### `ANSIBLE_SSH_PRIVATE_KEY_FILE`
- **What it is**: Absolute path to your SSH private key on the Ansible control node
- **Example**: `/root/.ssh/mykey.key` or `/home/user/.ssh/id_rsa`
- **How to obtain**:
  1. Generate SSH key (if you don't have one):
     ```bash
     ssh-keygen -t ed25519 -C "your-email@example.com"
     ```
  2. Copy public key to server:
     ```bash
     ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@ANSIBLE_HOST
     ```
  3. Use the path to your private key
- **Required**: ✅ Yes
- **Note**: This is the path on the **Ansible control node** (where you run `ansible-playbook`)

#### `ANSIBLE_PYTHON_INTERPRETER`
- **What it is**: Path to Python interpreter on the remote server
- **Example**: `/usr/bin/python3` or `/usr/bin/python3.11`
- **Default**: `/usr/bin/python3` (for Ubuntu 24.04)
- **How to check**: SSH to server and run `which python3`
- **Required**: ✅ Yes

## Generating Strong Random Values

### For Passwords and Secrets

**Python method** (recommended, most portable):
```bash
# 32-character random password
python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32)))"

# 128-character secret key
python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits + '!@#$%^&*') for _ in range(128)))"
```

**OpenSSL method**:
```bash
# 32-character password (base64 encoded, then truncated)
openssl rand -base64 24

# 128-character key
openssl rand -base64 96
```

**Linux/macOS command line**:
```bash
# Pure alphanumeric password
< /dev/urandom tr -dc 'A-Za-z0-9' | head -c 32; echo

# With special characters
< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*' | head -c 32; echo
```

## Example .env File

```env
# Core Infrastructure
ANSIBLE_HOST=203.0.113.45
BASE_DOMAIN=myservice.com
LETSENCRYPT_EMAIL=admin@myservice.com
TIMEZONE=America/Chicago

# Tailscale
TAILSCALE_AUTH_KEY=tskey-XXXXXXXXXXXXX

# Matrix
MATRIX_ADMIN_EMAIL=admin@myservice.com
MATRIX_DOMAIN=matrix.myservice.com
ELEMENT_DOMAIN=element.myservice.com
MATRIX_HOMESERVER_GENERIC_SECRET_KEY=aBc1d2E3f4G5h6I7j8K9l0M1n2O3p4Q5r6S7t8U9v0W1x2Y3z4A5b6
POSTGRES_CONNECTION_PASSWORD=VerySecurePassword123!@#

# Pelican
PELICAN_PANEL_DOMAIN=panel.myservice.com
PELICAN_WINGS_DOMAIN=wings.myservice.com
PELICAN_ADMIN_EMAIL=admin@myservice.com

# SSH/Ansible
ANSIBLE_USER=ubuntu
ANSIBLE_SSH_PRIVATE_KEY_FILE=/root/.ssh/myserver-key
ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3
```

## Troubleshooting

### "Variable lookup failed" Errors

If you see errors about environment variables not being found:

```
fatal: [homelab]: FAILED! => {"msg": "An unhandled exception occurred while executing a Jinja2 template."}
```

**Solution**: Make sure you've loaded the environment variables before running Ansible:
```bash
source .env
```

### Missing Required Variables

If Ansible complains about a missing variable:

1. Check the variable name is spelled correctly in `.env`
2. Verify the variable is actually set:
   ```bash
   echo $VARIABLE_NAME
   # Should print the value, not empty
   ```
3. Reload the environment:
   ```bash
   source .env
   unset HISTFILE  # Optional: prevent commands from history if you're paranoid
   ```

### Using Beyond initial Setup

For day-to-day operations, you don't need to keep environment variables loaded unless you're running Ansible again. However, it's recommended to keep them available in a secure location (like your password manager) for:
- Disaster recovery
- Configuration updates
- Infrastructure scaling

Suggested workflow:
1. Store in your password manager (1Password, Bitwarden, etc.)
2. Load and run Ansible when needed
3. Unload variables when done (`unset` each one or close shell)
4. Access `.env` file only when needed

## Security Best Practices

1. **Ownership and Permissions**:
   ```bash
   chmod 600 .env
   # Make sure only you can read it
   ls -la .env  # Should show -rw------- or -rw-r-----
   ```

2. **Encrypted Storage**:
   - Store `.env` in a password-protected archive
   - Or use git-crypt for encrypted version control
   - Or use a secrets management tool (HashiCorp Vault, AWS Secrets Manager)

3. **Rotation**:
   - Periodically change critical passwords
   - Especially if server access changes
   - Document rotation history

4. **Access Control**:
   - Limit who has access to `.env` file
   - Don't email or chat the file contents
   - Use secure transfer methods if sharing (or preferably, don't share)

5. **Cleanup**:
   - After setup, the `.env` file can be deleted from the control node
   - Keep a backup in secure storage
   - Never commit it to git

---

**Last Updated**: February 2026
