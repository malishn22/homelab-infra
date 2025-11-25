## How it works

- Docker network: `homelab` (external)
- Service: `nginx` (container name: `nginx-reverse-proxy`)
- Config: `conf.d/linkding.conf`
- Proxies: `http://linkding:9090` (Docker DNS name of the Linkding container)

## Usage

```bash
# 1. Copy the environment file (adjust if needed)
cp .env.example .env

# 2. Make sure the shared Docker network exists
docker network create homelab || true

# 3. Start the nginx reverse proxy
docker compose up -d

# 4. On your CLIENT machine, add this to /etc/hosts:
# <HOMELAB_IP>    bookmark.home

# Example:
# 192.168.1.42    bookmark.home

# After that, open this in your browser:
# http://bookmark.home

