# Jellyfin

Self-hosted media server running via docker compose, behind the global Nginx reverse proxy.

## How to run

```bash
cp .env.example .env   # edit values for your needs

# Make sure the shared Docker network exists
docker network create homelab || true

docker compose up -d
```

Then on your **client** machine, add this to `/etc/hosts`:

```
192.0.2.10    media.example.lan
```

and open <https://media.example.lan>.

> The shared cert is issued for `home.local`, so the browser will warn about a name
> mismatch on first visit — same as `bookmark.home` and `minecraft.home`. Accept and continue.

## Media libraries

Media lives at `/srv/media` on the host and is mounted **read-only** at `/media`.
Add each folder as its own library in the setup wizard — paths are case-sensitive:

| Host path                  | In container     | Library type |
| -------------------------- | ---------------- | ------------ |
| `/srv/media/movie`   | `/media/movie`   | Movies       |
| `/srv/media/tv`      | `/media/tv`      | Shows        |
| `/srv/media/anime`   | `/media/anime`   | Animes       |

Media sits outside this repo on purpose, so bulk files can never be committed by accident.

## Hardware transcoding

The compose file passes the AMD iGPU through (`/dev/dri`) and adds the `render` (992) and
`video` (44) groups. **This only makes VAAPI available — it is off by default.** Enable it once
in *Dashboard → Playback → Transcoding*: set hardware acceleration to **VAAPI** with device
`/dev/dri/renderD128`.

Verify the device is visible inside the container:

```bash
docker exec jellyfin ls -l /dev/dri
```

> The group IDs are specific to this host. If the machine is ever rebuilt, re-check them with
> `getent group render video` and update `group_add` — a stale GID disables hardware
> transcoding silently rather than throwing an error.

## Notes

- Runs on the `homelab` bridge network (not `network_mode: host`), so Nginx reaches it as
  `http://jellyfin:8096`. Trade-off: DLNA/client auto-discovery does not work; clients connect
  by URL.
- `config/` and `cache/` are bind-mounted next to this file, i.e. on `/home`. Keep them off
  `/var` — that is a 12G volume shared with all of `/var/lib/docker`, and transcode scratch
  files in `cache/` can grow large.
- Reverse proxy config lives in [`../nginx/conf.d/jellyfin.conf`](../nginx/conf.d/jellyfin.conf).
