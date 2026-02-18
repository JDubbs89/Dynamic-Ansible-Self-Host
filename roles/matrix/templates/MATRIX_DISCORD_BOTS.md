# Matrix Discord Bridge & Bots Setup Guide

## What's Included

Your enhanced Matrix config now has:

### Bridges
- ✅ **Discord Bridge** - Link Discord channels to Matrix rooms

### Bots
- ✅ **Mjolnir** - Moderation/admin bot (ban management, room protection)
- ✅ **Honoroit** - Help desk/support ticket system
- ✅ **Postmoogle** - Email-to-Matrix bridge (receive emails as messages)

### Admin Tools
- ✅ **Synapse Admin** - Web UI for user/room management
- ✅ **Element Call** - Video conferencing

### Performance
- ✅ PostgreSQL optimization
- ✅ Synapse cache tuning
- ✅ URL previews enabled
- ✅ 500MB upload limit

---

## DNS Records Required

Add these A records:
- `admin.yourdomain.com` → 147.224.210.58
- `call.yourdomain.com` → 147.224.210.58

---

## Setting Up the Discord Bridge

### 1. Create Discord Bot

**In Discord:**
1. Go to https://discord.com/developers/applications
2. Click "New Application"
3. Name it (e.g., "Matrix Bridge")
4. Go to "Bot" tab → "Add Bot"
5. **Copy the Bot Token** (you'll need this)
6. Enable these Privileged Gateway Intents:
   - Presence Intent
   - Server Members Intent
   - Message Content Intent
7. Go to "OAuth2" → "URL Generator"
   - Scopes: `bot`
   - Bot Permissions: `Administrator` (or specific permissions)
8. Copy the generated URL and visit it to invite bot to your Discord server

### 2. Configure the Bridge

After Matrix deploys, SSH into your server:

```bash
ssh ubuntu@147.224.210.58
cd /opt/homelab/matrix-docker-ansible-deploy

# Register the bridge
ansible-playbook -i inventory/hosts setup.yml --tags=setup-mautrix-discord,start

# Get the bridge login command
docker exec matrix-mautrix-discord /usr/bin/mautrix-discord -c /data/config.yaml -r /data/registration.yaml
```

### 3. Link Discord to Matrix

**In Element:**
1. Start a DM with `@discordbot:matrix.yourdomain.com`
2. Send: `login YOUR_DISCORD_BOT_TOKEN`
3. The bot will respond with login confirmation
4. To bridge a channel, invite the bot to a Matrix room
5. Send: `!discord bridge DISCORD_CHANNEL_ID`

**Get Discord Channel ID:**
- In Discord, enable Developer Mode (Settings → Advanced → Developer Mode)
- Right-click a channel → Copy Channel ID

---

## Setting Up Mjolnir (Moderation Bot)

### 1. Create Bot User

```bash
ssh ubuntu@147.224.210.58
cd /opt/homelab/matrix-docker-ansible-deploy

# Create the Mjolnir bot user
ansible-playbook -i inventory/hosts setup.yml \
  --tags=register-user \
  --extra-vars='username=mjolnir password=STRONG_PASSWORD admin=no'

# Get the access token
ansible-playbook -i inventory/hosts setup.yml \
  --tags=setup-bot-mjolnir
```

### 2. Configure Mjolnir

**In Element (as admin):**
1. Create a room called "Mjolnir Control Room" (private)
2. Invite `@mjolnir:matrix.yourdomain.com`
3. Make the bot admin in the room
4. The bot will respond with available commands

**Basic Commands:**
- `!mjolnir ban @user:server.com` - Ban a user
- `!mjolnir redact @user:server.com` - Remove all messages from user
- `!mjolnir rooms` - List protected rooms
- `!mjolnir rules` - Show active ban rules

---

## Setting Up Honoroit (Help Desk Bot)

### 1. Create Bot User

```bash
ssh ubuntu@147.224.210.58
cd /opt/homelab/matrix-docker-ansible-deploy

ansible-playbook -i inventory/hosts setup.yml \
  --tags=register-user \
  --extra-vars='username=honoroit password=STRONG_PASSWORD admin=no'
```

### 2. Configure Support Room

**In Element:**
1. Create a public room called "Support"
2. Invite `@honoroit:matrix.yourdomain.com`
3. Users can now create support tickets by messaging in this room
4. Tickets are tracked and can be assigned/resolved

**Commands:**
- `!ho help` - Show help
- `!ho create [title]` - Create a ticket
- `!ho assign [ticket-id] @user` - Assign ticket
- `!ho close [ticket-id]` - Close ticket

---

## Setting Up Postmoogle (Email Bridge)

### 1. Configure After Deployment

```bash
ssh ubuntu@147.224.210.58
cd /opt/homelab/matrix-docker-ansible-deploy

# The bot auto-registers on first run
docker logs matrix-bot-postmoogle
```

### 2. Use Email Bridge

**In Element:**
1. Start DM with `@postmoogle:matrix.yourdomain.com`
2. Send: `!pm help`
3. Configure an email mailbox:
   ```
   !pm mailbox add
   Server: imap.gmail.com
   Username: your@email.com
   Password: your_app_password
   ```
4. Emails will now appear as Matrix messages

---

## Accessing Synapse Admin

1. Visit `https://admin.yourdomain.com`
2. **Homeserver URL**: `https://matrix.yourdomain.com`
3. Login with your admin Matrix user

**Create admin user if needed:**
```bash
ssh ubuntu@147.224.210.58
cd /opt/homelab/matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts setup.yml \
  --tags=register-user \
  --extra-vars='username=admin password=YourPassword admin=yes'
```

---

## Using Element Call

**For video conferences:**
1. In any Matrix room, click the call button
2. Select "Element Call" (not Jitsi)
3. Share the room link with participants

Or visit `https://call.yourdomain.com` directly.

---

## Performance Notes

The PostgreSQL and Synapse optimizations are tuned for:
- 2-4 vCPUs
- 4-8GB RAM
- ~50-100 active users

If you have more/less resources, adjust in `matrix-vars.yml.j2`:

```yaml
# For 1-2 vCPUs, reduce:
matrix_synapse_caches_global_factor: 0.5

# For 8+ vCPUs, increase:
matrix_synapse_caches_global_factor: 2.0
```

---

## Troubleshooting

### Discord Bridge Not Responding

```bash
# Check bridge logs
docker logs matrix-mautrix-discord

# Restart bridge
cd /opt/homelab/matrix-docker-ansible-deploy
ansible-playbook -i inventory/hosts setup.yml --tags=setup-mautrix-discord,start
```

### Bots Not Appearing

```bash
# Check if bot containers are running
docker ps | grep matrix-bot

# Restart a specific bot
docker restart matrix-bot-mjolnir
```

### Admin Panel 403 Error

You need to login with an admin user. Verify your user is admin:
```bash
ssh ubuntu@147.224.210.58
docker exec matrix-postgres psql -U synapse -d synapse -c \
  "SELECT name, admin FROM users WHERE name='@admin:matrix.yourdomain.com';"
```

Should show `admin | t` (true). If not, promote the user:
```bash
docker exec matrix-synapse \
  register_new_matrix_user -c /data/homeserver.yaml -a -u admin
```

---

## Next Steps

1. **Replace your `matrix-vars.yml.j2`** with the final version
2. **Add DNS records** for admin and call subdomains
3. **Re-run Matrix deployment**:
   ```powershell
   ansible-playbook -i inventory/hosts.yml site.yml --tags=matrix
   ```
4. **Set up Discord bridge** following steps above
5. **Configure bots** for your use case

The deployment will take ~15-20 minutes to pull all the additional images and configure everything.
