# Traefik + Tailscale Architecture Analysis

## Overview

Your deployment uses a **two-layer security model**:

1. **Tailscale VPN** - provides encrypted tunnel and private network access
2. **Traefik Reverse Proxy** - handles HTTP/HTTPS routing and SSL termination

---

## Current Architecture

### Layer 1: Tailscale (Network Level)

```
┌─────────────────────────────────────────┐
│  Your Local Machine (Tailscale Client)  │
│  └─ tailscale0 interface (e.g. 100.*)   │
└────────────────────┬────────────────────┘
                     │ Encrypted VPN Tunnel
                     │ (Wireguard-based)
                     ▼
         ┌───────────────────────────────┐
         │  Your Server (Tailscale Node) │
         │  ├─ tailscale0: 100.x.x.x     │
         │  └─ eth0: YOUR_PUBLIC_IP      │
         └───────────────────────────────┘
```

**Role:** `roles/tailscale/tasks/main.yml`
- Installs Tailscale daemon (`tailscaled`)
- Authenticates via auth key: `tailscale_auth_key` from `group_vars/all.yml`
- Retrieves Tailscale IP: `tailscale ip -4` (e.g., `100.64.0.42`)
- Services are **NOT bound to Tailscale interface** — they listen on localhost or Docker networks

**Key Point:** Tailscale provides **network-level encryption** but doesn't directly restrict HTTP access. Access control happens at the Traefik level.

---

### Layer 2: Traefik (HTTP Routing Level)

```
                    Internet (YOUR_PUBLIC_IP)
                              │
        ┌─────────────────────▼─────────────────────┐
        │ Traefik Container (traefik Docker network)│
        │ ├─ Port 80 (HTTP)                         │
        │ ├─ Port 443 (HTTPS)                       │
        │ └─ Dashboard: traefik.yourdomain.com      │
        └──────────────┬──────────────┬──────────────┘
                       │              │
         ┌─────────────▼──┐  ┌────────▼──────────┐
         │ Matrix Services│  │ Pelican Services  │
         ├─ synapse:8008  │  ├─ panel:80         │
         └─────────────────┘  ├─ wings:443        │
                              └────────────────────┘
```

**Role:** `roles/traefik/tasks/main.yml` + `roles/traefik/templates/`

**Static Config (`traefik.yml.j2`):**
- Defines entry points: `:80` (web) and `:443` (web-secure)
- Loads dynamic routes from `/etc/traefik/dynamic.yml` with file watching
- Docker provider: auto-discovers labeled services
- Certificate resolvers: dummy placeholders (not used; self-signed certs instead)

**Dynamic Config (`dynamic.yml.j2`):**
```yaml
middlewares:
  tailscale-only:
    ipWhiteList:
      sourceRange:
        - "100.64.0.0/10"  # Tailscale CGNAT range
```

⚠️ **CRITICAL:** This middleware **exists but is not applied to any router**. Services are currently **publicly accessible** to anyone on the internet.

---

## Current Routing Rules

### Matrix Services

**File:** `roles/matrix/templates/traefik-matrix-routes.yml.j2`

```yaml
routers:
  matrix-synapse-public-client-https:
    rule: "Host(`matrix.yourdomain.com`)"
    entrypoints: web-secure
    service: matrix-synapse-client
    # NO MIDDLEWARE - publicly accessible
```

**Services:** Each router maps to a backend service via **Host header matching**:
- `matrix.yourdomain.com` → `matrix-synapse:8008` (port 8008)
- `element.yourdomain.com` → `matrix-client-element:80` (web UI)
- `call.yourdomain.com` → `matrix-client-element-call:7780` (voice/video)

### Pelican Services

**File:** `roles/pelican/templates/docker-compose.yml.j2`

```yaml
labels:
  - "traefik.http.routers.pelican-panel.rule=Host(`panel.yourdomain.com`)"
  - "traefik.http.routers.pelican-panel.entrypoints=web-secure"
  - "traefik.http.routers.pelican-panel.tls=true"
```

Same pattern: **Host-based routing** (one service per domain).

---

## How Traefik Discovers & Routes

### 1. Docker Label-Based Discovery

Traefik monitors `/var/run/docker.sock` for labeled containers:

```yaml
traefik.enable=true                                    # Enable routing for this service
traefik.http.routers.pelican-panel.rule=Host(`...`)  # Route rule (Host, PathPrefix, etc.)
traefik.http.routers.pelican-panel.service=srv        # Which service backend to use
traefik.http.services.pelican-panel.loadbalancer...   # Backend server details
```

**Advantage:** New services auto-register without editing Traefik config.

### 2. File-Based Routes (Matrix)

`site.yml` post-tasks dynamically inject Matrix routes:

```yaml
post_tasks:
  - name: Generate Matrix Traefik routes
    template:
      src: roles/matrix/templates/traefik-matrix-routes.yml.j2
      dest: /opt/homelab/traefik/config/matrix-routes.yml
  
  - name: Append Matrix routes to dynamic config
    shell: |
      cat /opt/homelab/traefik/config/matrix-routes.yml >> /opt/homelab/traefik/config/dynamic.yml
    notify: restart traefik
```

**Note:** Matrix uses a separate Ansible deployment (`matrix-docker-ansible-deploy`), so routes are injected from outside.

**Directory structure:**
```
/opt/homelab/traefik/
├── config/
│   ├── traefik.yml          # Static config
│   ├── dynamic.yml          # Dynamic routes (concatenated)
│   └── matrix-routes.yml    # Matrix-specific routes (appended)
└── letsencrypt/
    └── acme.json            # ACME certificate storage
```

---

## Current Access Model

| Service | URL | Access | Notes |
|---------|-----|--------|-------|
| Matrix Synapse | `https://matrix.yourdomain.com` | 🌍 Public | Client API, federation (disabled) |
| Element Web | `https://element.yourdomain.com` | 🌍 Public | Web UI for matrix |
| Pelican Panel | `https://panel.yourdomain.com` | 🌍 Public | Game server management |
| Traefik Dashboard | `https://traefik.yourdomain.com` | 🌍 Public | ⚠️ No auth configured |

**All services are publicly accessible.** Tailscale provides encryption in-transit but does NOT gate access at the Traefik level.

---

## Goal: `fragnocklegacy.com/{service_name}` with Tailscale-Only Access

### Current Limitations

Your setup uses **Host-based routing** (one domain = one service). To implement `fragnocklegacy.com/matrix`, `fragnocklegacy.com/pelican`, etc., you need **Path-based routing**.

### Required Changes

#### 1. **Add Path-Based Routers to `dynamic.yml.j2`**

Instead of separate hosts, use path prefixes:

```yaml
http:
  routers:
    # Catch fragnocklegacy.com and route by path
    matrix-synapse-vlan:
      rule: "Host(`fragnocklegacy.com`) && PathPrefix(`/matrix`)"
      entrypoints: web-secure
      service: matrix-synapse-client
      middlewares:
        - tailscale-only          # Restrict to VPN
        - matrix-strip-prefix     # Remove /matrix prefix before forwarding
      tls: {}

    pelican-panel-vlan:
      rule: "Host(`fragnocklegacy.com`) && PathPrefix(`/pelican`)"
      entrypoints: web-secure
      service: pelican-panel
      middlewares:
        - tailscale-only
        - pelican-strip-prefix
      tls: {}

    minecraft-vlan:
      rule: "Host(`fragnocklegacy.com`) && PathPrefix(`/minecraft`)"
      entrypoints: web-secure
      service: minecraft
      middlewares:
        - tailscale-only
      tls: {}

  services:
    matrix-synapse-client:
      loadBalancer:
        servers:
          - url: "http://matrix-synapse:8008"

    pelican-panel:
      loadBalancer:
        servers:
          - url: "http://pelican_panel:80"

  middlewares:
    # Restrict to Tailscale IP range (100.64.0.0/10)
    tailscale-only:
      ipWhiteList:
        sourceRange:
          - "100.64.0.0/10"

    # Strip /matrix prefix before proxy (Matrix API expects /, not /matrix)
    matrix-strip-prefix:
      stripPrefix:
        prefixes:
          - "/matrix"
        forceSlash: true

    # Strip /pelican, keep path for Pelican router
    pelican-strip-prefix:
      stripPrefix:
        prefixes:
          - "/pelican"
        forceSlash: false
```

#### 2. **DNS Configuration**

Add a DNS record:

```
fragnocklegacy.com  A  YOUR_SERVER_IP
```

#### 3. **How Access Control Works**

When a client connects via Tailscale:

```
Client:
  Local tailscale0 IP: 100.64.x.y (from Tailscale)
         ↓
  Request: GET https://fragnocklegacy.com/matrix → HTTP Host: fragnocklegacy.com, Client IP: 100.64.x.y
         ↓
Traefik:
  1. Matches route rule: Host(`fragnocklegacy.com`) && PathPrefix(`/matrix`) ✓
  2. Checks tailscale-only middleware: Client IP in 100.64.0.0/10? ✓ Yes
  3. Strips /matrix from path
  4. Proxies to matrix-synapse:8008 with path=/
         ↓
Matrix API:
  Receives: GET http://matrix-synapse:8008/ (internal Docker network)
  Responds normally
```

If someone tries from the internet (without Tailscale):

```
Client: 8.8.8.8 (Google DNS, for example)
  Request: GET https://fragnocklegacy.com/matrix → Client IP: 8.8.8.8
         ↓
Traefik:
  1. Matches route rule ✓
  2. Checks tailscale-only middleware: 8.8.8.8 in 100.64.0.0/10? ✗ No
  3. Returns: 403 Forbidden (IP not whitelisted)
```

---

## Architecture Diagram: Proposed Changes

```
                         Internet
                            │
        YOU (Tailscale Client)    ATTACKER
            100.64.x.y                8.8.8.8
                │                       │
                └───────────┬───────────┘
                            ▼
         ┌──────────────────────────────────────┐
         │ Traefik (fragnocklegacy.com:443)     │
         └─────────────────┬────────────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         PathPrefix      ipWhiteList   PathPrefix
         /matrix        100.64.0.0/10  /pelican
              │            │            │
              ▼            ▼            ▼
    ✓ ALLOWED          ✓ ALLOWED    ✓ ALLOWED
         │                                │
    ┌────▼─────┐    ┌─────────────┐  ┌──▼──────┐
    │  Matrix   │    │  Pelican    │  │Minecraft│
    │ API:8008  │    │  Panel:80   │  │  (TCP)  │
    └───────────┘    └─────────────┘  └─────────┘

    ✗ NOT ALLOWED (8.8.8.8)
         │
         ▼
    [403 Forbidden]
```

---

## Implementation Steps

### Phase 1: Update Traefik Dynamic Config

1. Edit `roles/traefik/templates/dynamic.yml.j2`
2. Add path-based routers for each service
3. Apply the `tailscale-only` middleware to each

### Phase 2: Update Service Configs

3. Update `roles/pelican/templates/docker-compose.yml.j2` - add labels for path-based routing
4. Update `roles/matrix/templates/traefik-matrix-routes.yml.j2` - replace Host rules with path rules

### Phase 3: Test & Deploy

5. Run playbook with `--tags traefik`
6. Verify: SSH into server, test with curl from your Tailscale IP

---

## Testing from Server

```bash
# SSH into your server via Tailscale
ssh ubuntu@YOUR_TAILSCALE_IP

# Get your Tailscale IP for auth header testing (if needed later)
tailscale ip -4
# Output: 100.64.x.y

# Test internal Matrix API (should work)
curl -k https://fragnocklegacy.com/matrix/_matrix/client/versions

# Test from public internet (should fail with 403 if you're not on Tailscale)
# From your local machine NOT on Tailscale:
curl https://fragnocklegacy.com/matrix
# Expected: 403 Forbidden (IP not in whitelist)

# Test from Tailscale (should work)
# From your local machine WITH Tailscale connected:
curl https://fragnocklegacy.com/matrix
# Expected: 200 OK
```

---

## Key Considerations

### 1. **Client IP Detection**

- ✅ Works: Clients connect via Tailscale VPN → their Tailscale IP is forwarded
- ⚠️ Note: Docker internal IP (`10.0.0.0/8`, `172.16.0.0/12`) will be allowed if services are on the same network
- ⚠️ Fix: Use Docker user-defined networks (already using `traefik` network)

### 2. **Path Stripping**

- Matrix API expects root path `/` (not `/matrix`)
- Use `stripPrefix` middleware to remove `/ matrix` before proxying
- Pelican may handle prefixes differently — test after deployment

### 3. **Certificate Strategy**

- Currently using self-signed certs (not ACME)
- Traefik will use the same certificate for `fragnocklegacy.com`
- Browser will show cert warning unless you import the cert to Tailscale client

### 4. **TLS with 100.64.0.0/10**

- ✅ Good security: Tailscale encrypts traffic at VPN layer
- ✅ Traefik TLS adds another layer (defense in depth)
- Clients won't get warnings if:
  - They trust the self-signed cert
  - OR You use a public cert (requires public internet access — defeats VPN purpose, NOT recommended)

---

## Summary: Traefik ↔ Tailscale Interaction

| Layer | Component | Responsibility |
|-------|-----------|-----------------|
| **Network** | Tailscale | Encrypt traffic, assign private IP (100.64.x.x) |
| **Transport** | HTTPS/TLS | Encrypt HTTP Layer 7 traffic |
| **Routing** | Traefik | Route based on Host + Path, apply IP whitelist middleware |
| **Access Control** | `tailscale-only` middleware | Block non-Tailscale IPs with 403 |

Current state: ✅ Tailscale configured, ❌ `tailscale-only` not enforced in routes, ❌ Path-based routing not implemented.

Goal achievable with changes to:
1. `roles/traefik/templates/dynamic.yml.j2` (path routers + apply middleware)
2. `roles/matrix/templates/traefik-matrix-routes.yml.j2` (replace Host rules)
3. `roles/pelican/templates/docker-compose.yml.j2` (update labels)

