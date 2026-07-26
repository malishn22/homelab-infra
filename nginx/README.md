# Nginx Reverse Proxy

The single entry point for every HTTP service in the homelab. Terminates ports 80 and 443 on the
host and routes to the right container based on the `Host` header.

## How it works

- **Docker network:** `homelab` (external) — nginx must share it with every service it proxies.
- **Container:** `nginx-container`
- **Config:** `conf.d/*.conf`, one file per virtual host, mounted into the container
- **Certificates:** `certs/`, mounted read-only. Not tracked in git.

Because everything sits on the shared `homelab` bridge network, nginx addresses backends by
**container name** — `proxy_pass http://linkding:9090` — and Docker's embedded DNS resolves it. No
IP addresses appear in any config.

### Virtual hosts

| File | `server_name` | Upstream |
|---|---|---|
| `linkding.conf` | `bookmark.home` | `linkding:9090` |
| `jellyfin.conf.template` | `${JELLYFIN_SERVER_NAME}` | `jellyfin:8096` |
| `minecraft.conf` | `minecraft.home` | `ghms-frontend` (via `resolver`) |
| `calimali-api.conf.template` | `${CALIMALI_PUBLIC_HOST}` *(HTTP only — TLS upstream)* | `calimali-api:8080` |
| `stub_status.conf` | `_` | exposes `/stub_status` for `nginx-exporter` |

## Usage

```bash
# 1. Copy the environment file (adjust if needed)
cp .env.example .env

# 2. Make sure the shared Docker network exists
docker network create homelab || true

# 3. Start the nginx reverse proxy
docker compose up -d

# 4. On your CLIENT machine, add the hostnames to /etc/hosts:
#    192.0.2.10    bookmark.home minecraft.home media.example.lan
```

The `.home` and `.jellyfin` suffixes are not real DNS. Each client resolves them through its own
`/etc/hosts`; nginx then matches the name with `server_name`. Adding a service means adding an
entry on every client machine that needs to reach it.

## Caveats

**Hostname resolution happens at config-load time.** nginx resolves a literal `proxy_pass` hostname
once, when the config is parsed — not per request. Two consequences:

1. If the upstream container is down when nginx starts, that vhost stays broken until nginx is
   reloaded, even after the container comes back. `docker compose restart nginx` fixes it.
2. `nginx -t` fails in CI unless the name resolves there too. `.github/workflows/nginx-ci.yml`
   therefore passes an `--add-host` stub for `linkding`. **Adding a static vhost means adding a
   stub, or the build goes red.**

`minecraft.conf` sidesteps this by declaring a `resolver` and using a variable in `proxy_pass`,
which defers resolution to request time. That is why it needs no `--add-host` entry. The
`jellyfin`/`calimali-api` vhosts are rendered only at container start (see below), so CI's
`nginx -t` never sees them and they need no stub either.

**TLS.** Certificates live in `certs/` and are bind-mounted read-only. They are self-signed, so
browsers warn on first visit. The certificate's Common Name must match the `server_name` being
requested — a mismatch produces a name-mismatch error that reads like a proxy failure but isn't.
CI generates a throwaway `home.local` certificate rather than using the real ones.

**Public hostnames stay out of git.** `jellyfin` and `calimali-api` are defined in
`templates/*.template`, taking their `server_name` from `.env` (`JELLYFIN_SERVER_NAME`,
`CALIMALI_PUBLIC_HOST`). At container start the nginx image's `envsubst` renders them into `conf.d/`
(its default output dir); the resulting `conf.d/{jellyfin,calimali-api}.conf` are **gitignored**, so
the real hostnames are never committed. `NGINX_ENVSUBST_FILTER` restricts substitution to those two
vars, leaving nginx's own `$host`, `$scheme`, `$http_upgrade`, etc. intact.

**`calimali-api` is HTTP-only by design** (no 443 redirect): its TLS is terminated upstream at the
public edge, and access is gated by the application's own JWT rather than the network.
