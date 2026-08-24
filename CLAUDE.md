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
  exporting means the next provisioning pass overwrites the change. The provider globs the whole
  `grafana/dashboards/` directory, so adding a dashboard needs no YAML change and no restart —
  Grafana re-reads the directory roughly every 10 s. Deleting the file deletes the dashboard.
- The datasource uids are `prometheus-homelab` and `loki-homelab`, hardcoded in every panel. A
  dashboard exported from the UI may carry a different uid and will render empty — check before
  committing.
- **Five dashboards**, split application vs infrastructure:
  `ghms.json`, `spotify-archiver.json` — the two applications.
  `host.json` (Host Machine), `containers.json` (Containers), `system-ci.json` (System Services &
  CI) — the same machine at three layers: the hardware, the 20 containers, and the non-container
  load (systemd slices and the four CI runners, which are *not* containers and so are invisible to
  any cAdvisor query filtered to real containers).

### PromQL traps on this host — read before writing a panel

Every one of these was hit while building the infra dashboards. Full detail in
`monitoring/README.md`.

- node-exporter is scraped as job **`node`**, not `node-exporter`. cAdvisor is job `cadvisor`.
- **node-exporter cannot see the host's NICs.** It runs on the `homelab` bridge, and
  `/proc/net/dev` is generated per *network namespace* — resolved from the reading process, not
  the mount it came through — so `--path.rootfs=/host` does not help. `node_network_*` is this
  container's own veth (i.e. scrape traffic). Host NIC throughput comes from cAdvisor's root
  cgroup: `container_network_*{id="/", interface=~"eno1|wlp3s0|tailscale0"}`.
- **Every cAdvisor container query needs `name!=""`.** Only 20 of ~64 CPU series are containers;
  the rest are systemd slices and the root cgroup, and the root cgroup is the entire machine.
- **GHMS game servers carry no Compose labels** — GHMS creates them through the Docker socket, not
  Compose. An absent label is the empty string, so a
  `container_label_com_docker_compose_project=~".+"` filter silently drops the whole game-server
  fleet. The Stack template variable uses `allValue: ".*"` for exactly this reason.
- **Counting series is not counting containers.** After a redeploy the replaced container keeps
  reporting under its old cgroup id for ~5 min (Prometheus' lookback), so `count(...)` over-reports.
  Count distinct names, or aggregate with `max by (name, ...)`.
- **Nothing sets a CPU limit**, so `container_spec_cpu_quota` does not exist at all and
  percent-of-limit panels are impossible. `container_spec_memory_limit_bytes` is 0 except on a
  *running* GHMS game server. Usage is expressed as a percentage of the host (16 cores / 29.2 GB).
- `node_filesystem_*` reports three phantom `/etc/*` mounts (Docker's own bind mounts inside the
  exporter); `nvme0n1` and `dm-*` double-count the same I/O and must never be summed together.
- **`count(up == 0)` returns no series when everything is healthy**, which a stat panel renders as
  "No data" — precisely the ambiguity a scrape-health tile exists to remove. Use
  `min(up{job=~"..."})`, which always returns a value, or append `or vector(0)`. Every dashboard
  carries a `Scrape health` tile scoped to the jobs it actually queries, because a dead exporter
  and a quiet system produce identical empty graphs.
- Loki rejects a selector whose every matcher is empty-compatible, so a logs panel needs at least
  one `=~".+"` matcher. An empty logs panel usually means the stack is simply quiet — the
  `Lines in last 7d` tile on the Containers dashboard exists to tell those two cases apart.

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
