# Linkding

Self-hosted bookmark manager, running via Docker Compose behind the homelab nginx reverse proxy.

- **Container:** `linkding`
- **Port:** `9090` on the host
- **LAN URL:** `http://bookmark.home` (via nginx — see `../nginx/README.md`)
- **Data:** `./data`, a bind mount holding the SQLite database and uploads

## How to run

```bash
cp .env.example .env      # set the initial superuser credentials
docker network create homelab || true
docker compose up -d
```

On a client machine, add the hostname to `/etc/hosts` so nginx can route to it:

```
192.0.2.10    bookmark.home
```

## Caveats

- **`data/` is the entire application state** and is gitignored. Backing up Linkding means copying
  that directory — there is nothing else to save.
- It is a bind mount rather than a named volume on purpose: named volumes live under
  `/var/lib/docker`, which on this host is a 12 G LVM volume and the tightest filesystem.
  Bind-mounting to `/home` keeps the data off it.
- The superuser variables in `.env` only take effect on **first** start, when the database is
  created. Changing them later does nothing — use the Linkding UI to change the password.
