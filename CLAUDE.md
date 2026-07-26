# homelab-infra — working notes

Infrastructure for a single Debian host: reverse proxy, monitoring, media, bookmarks. `README.md`
is the public-facing overview; this file is the set of conventions and traps that aren't obvious
from reading the tree.

This repo is portfolio-facing. Docs here are read by strangers — keep them accurate, and keep the
structure tree in `README.md` in sync when directories change.

## Conventions

- **Commits**: plain imperative, sentence case, no Conventional Commits prefixes.
  Real examples: "Add weekly Docker cleanup script", "Cap Prometheus TSDB retention to bound /var
  growth", "Proxy Jellyfin at media.example.lan". The body explains *why*, and specifically names
  any constraint that is invisible from the diff.
- **A stack is done** when it has all four of: `docker-compose.yml`, `.env`, `.env.example`,
  `README.md`. `jellyfin/README.md` is the model to copy — run steps, then a caveats section that
  names the specific trap.
- Every stack joins the **external** bridge network `homelab` (`external: true`). Compose must not
  create its own, or containers stop resolving each other by name.

## nginx — the CI coupling

nginx resolves literal `proxy_pass` hostnames **at config-load time**, not per request. So
`nginx -t` fails if the upstream name doesn't resolve, even though the config is syntactically
fine.

**Adding or editing a vhost in `nginx/conf.d/` therefore requires adding a matching `--add-host`
stub to `.github/workflows/nginx-ci.yml`**, or the build goes red. That is why `linkding`,
`calimali-api`, and `jellyfin` are listed there. `minecraft.conf` is the exception that proves it:
it uses a `resolver` with a variable `proxy_pass`, which defers resolution to request time and so
needs no stub.

Same mechanism at runtime: a vhost pointing at a container that was down when nginx started keeps
failing until nginx is reloaded.

CI runs on `ubuntu-latest`, not on the self-hosted runners — it only needs `docker compose config`
and a containerised `nginx -t`.

## Monitoring

- Dashboards are **JSON in git**, and git is the source of truth. Editing in the Grafana UI without
  exporting means the next provisioning pass overwrites the change.
- The datasource uid is `prometheus-homelab`. A dashboard exported from the UI may carry a
  different uid and will render empty — check before committing.
- The stack is larger than `monitoring/README.md` currently says: alongside Prometheus, Grafana,
  node-exporter and nginx-exporter it also runs **cAdvisor, Loki, and Promtail**.

## Retention — read before touching

The Prometheus TSDB retention flags are enforced against data that **already exists**, not just
future growth, and the stricter of time/size wins. Setting either below current usage deletes the
oldest blocks on the next start. Applying this once dropped ~15 days of metrics.

Snapshot the volume and quantify the loss before lowering either. A `PreToolUse` hook blocks edits
touching those flags for exactly this reason.

## Disk

`/var` is a separate 12 G LVM volume holding `/var/lib/docker`, running around 75 % full — the
scarce resource on this host. Named volumes and images land there; bind mounts to `/home/...` do
not. That is why `jellyfin/config` and `jellyfin/cache` are bind mounts: transcode scratch would
otherwise fill `/var`.

`scripts/docker-cleanup.sh` runs weekly via cron (`0 4 * * 0`) and prunes images, build cache, and
stopped containers older than 168h. It appends to `scripts/docker-cleanup.log`, printing
`df -h /var` before and after — that log is the **only** record the prune ran, because this host
does not capture cron `CMD` lines in the journal.

## Never commit

Any `.env`, `nginx/certs/`, the env-rendered `nginx/conf.d/{calimali-api,jellyfin}.conf` (they
carry the real public hostnames), `jellyfin/config/`, `jellyfin/cache/`, `linkding/data/`, and
`scripts/docker-cleanup.log`.

## Known rough edges

- The `jellyfin` and `calimali-api` vhosts are env-rendered templates: `templates/*.template` →
  `conf.d/` at container start via envsubst, with `server_name` from `.env`. The rendered
  `conf.d/{jellyfin,calimali-api}.conf` are gitignored so the real hostnames aren't committed.
  `calimali-api` is intentionally HTTP-only (TLS terminated upstream; JWT-gated) — not a bug,
  don't "fix" it to 443.
- `infra/.env` exists at the repo root, referenced by no README.
- Nothing rotates the runner `_diag` logs — see `ci/README.md`.
