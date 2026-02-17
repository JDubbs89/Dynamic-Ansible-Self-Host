# dynamic-ansible-self-host

A modular Ansible playbook for self-hosting multiple services on a single server behind a shared Traefik reverse proxy. Designed to be extended — adding a new service means adding a role and a line in `site.yml`.

> **Current stack:** Matrix (Synapse + Element) via [matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy), Pelican Panel + Wings for game server management, and Traefik for SSL termination and routing.

---

## Architecture Overview

```
                        Internet
                           │
                     ┌─────▼─────┐
                     │  Traefik  │  ← SSL termination, cert management
                     └─────┬─────┘
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐  ┌──▼──────┐  ┌──▼────────────┐
       │   Matrix    │  │ Element │  │ Pelican Panel  │
       │  (Synapse)  │  │  (Web)  │  │   + Wings      │
       └─────────────┘  └─────────┘  └────────────────┘
```

Traefik runs as the single entry point. Every service joins the shared `traefik` Docker network and registers itself via container labels — no manual Traefik config required when adding services.

Game server ports (e.g. Minecraft 25565) are exposed directly and bypass Traefik, as raw TCP cannot be HTTP-proxied.

---

## Prerequisites

**Your server:**
- Ubuntu 24.04 LTS
- Minimum 2 vCPU, 4GB RAM (Oracle Cloud Free Tier Ampere A1 works)
- A domain name with DNS you control

**Your local machine:**
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) `>= 2.14`
- `git`
- SSH access to your server

**DNS records required (all pointing to your server's public IP):**
| Record | Purpose |
|---|---|
| `matrix.yourdomain.com` | Matrix homeserver |
| `element.yourdomain.com` | Element web client |
| `panel.yourdomain.com` | Pelican Panel UI |
| `wings.yourdomain.com` | Pelican Wings API |

---

## Repository Structure

```
dynamic-ansible-self-host/
├── inventory/
│   └── hosts.yml               # Your server connection details
├── group_vars/
│   └── all.yml                 # Shared config: domain, email, timezone
├── roles/
│   ├── base/                   # Docker, git, firewall, system prep
│   ├── traefik/                # Traefik reverse proxy + cert management
│   ├── matrix/                 # Wraps MDAD (git submodule)
│   └── pelican/                # Pelican Panel + Wings
├── services/
│   └── pelican/
│       ├── docker-compose.yml  # Pelican compose with Traefik labels
│       └── Caddyfile           # Internal Panel web server config
├── site.yml                    # Master playbook — runs all roles
└── README.md
```

---

## Quick Start

### 1. Clone the repository

```bash
git clone --recurse-submodules https://github.com/yourusername/dynamic-ansible-self-host.git
cd dynamic-ansible-self-host
```

### 2. Configure your inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  hosts:
    homelab:
      ansible_host: YOUR_SERVER_IP
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/your_key
```

### 3. Set your variables

Edit `group_vars/all.yml`:

```yaml
base_domain: yourdomain.com
letsencrypt_email: you@example.com
timezone: America/New_York

# Derived — do not edit
matrix_domain: "matrix.{{ base_domain }}"
element_domain: "element.{{ base_domain }}"
pelican_panel_domain: "panel.{{ base_domain }}"
pelican_wings_domain: "wings.{{ base_domain }}"
```

### 4. Run the playbook

```bash
# Full install
ansible-playbook -i inventory/hosts.yml site.yml

# Only run a specific service
ansible-playbook -i inventory/hosts.yml site.yml --tags pelican
ansible-playbook -i inventory/hosts.yml site.yml --tags matrix
```

---

## Oracle Cloud Firewall Note

Oracle Cloud blocks all ports by default at two levels. You need to open ports in **both** places:

**1. OCI Security List** (Oracle Cloud Console → Networking → VCN → Security Lists):

| Port | Protocol | Purpose |
|---|---|---|
| 22 | TCP | SSH |
| 80 | TCP | Traefik HTTP / ACME challenges |
| 443 | TCP | Traefik HTTPS |
| 2022 | TCP | Pelican Wings SFTP |
| 8443 | TCP | Pelican Wings API |
| 25565 | TCP + UDP | Minecraft (default port) |

**2. Host-level iptables** — Ubuntu on Oracle ships with rules that block everything regardless of the Security List. The base role handles this automatically, but if you're doing manual setup:

```bash
sudo iptables -F
sudo netfilter-persistent save
```

---

## Adding a New Service

This playbook is designed to grow. To add a new service:

1. Create a role under `roles/yourservice/`
2. Add a `docker-compose.yml` under `services/yourservice/` with Traefik labels pointing at the shared `traefik` network
3. Add a DNS record for the service's subdomain
4. Add the role to `site.yml`:

```yaml
- name: Deploy your service
  hosts: all
  roles:
    - role: yourservice
      tags: yourservice
```

5. Run: `ansible-playbook -i inventory/hosts.yml site.yml --tags yourservice`

For HTTP services, Traefik handles SSL automatically via Let's Encrypt. No additional Traefik configuration required.

---

## Services Reference

### Matrix (Synapse + Element)

Managed via [matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy) as a git submodule. Traefik is configured to use MDAD's own Traefik instance as the shared proxy for all services.

- Panel: `https://element.yourdomain.com`
- Homeserver: `https://matrix.yourdomain.com`
- Federation port: `8448` (handled by MDAD's Traefik)

Refer to the [MDAD documentation](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/README.md) for Matrix-specific configuration (bridges, bots, etc.).

### Pelican Panel + Wings

Web-based game server management panel. Panel is proxied through Traefik. Wings (the node daemon) exposes ports directly.

- Panel UI: `https://panel.yourdomain.com`
- Wings API: `https://wings.yourdomain.com`
- SFTP: `your-server-ip:2022`
- Game server ports: `25565` (Minecraft default), configurable in Panel

After first deploy, visit `https://panel.yourdomain.com/installer` to complete setup.

---

## Updating Services

```bash
# Update all services
ansible-playbook -i inventory/hosts.yml site.yml

# Update MDAD (Matrix) submodule to latest
git submodule update --remote roles/matrix/mdad
ansible-playbook -i inventory/hosts.yml site.yml --tags matrix

# Rebuild Pelican images (new Panel/Wings release)
ansible-playbook -i inventory/hosts.yml site.yml --tags pelican --extra-vars "pelican_force_rebuild=true"
```

---

## Troubleshooting

**Traefik not picking up a service:**
```bash
# Check Traefik logs
docker logs traefik

# Verify the service is on the traefik network
docker network inspect traefik
```

**Pelican Wings shows no green heart in Panel:**
```bash
# Check Wings logs
docker logs pelican_wings

# Verify config.yml exists and ssl.enabled is false
cat /etc/pelican/config.yml | grep ssl
```

**Certificate not issuing:**
- Confirm DNS A records are propagated: `dig panel.yourdomain.com`
- Confirm port 80 is open (ACME HTTP challenge requires it)
- Check Traefik logs for ACME errors

---

## Contributing

Pull requests for new service roles are welcome. To keep things consistent, new roles should:

- Use the shared `traefik` Docker network for HTTP services
- Accept configuration exclusively through `group_vars/all.yml` variables
- Include an `uninstall.yml` task file
- Be tagged in `site.yml`

---

## License

MIT
