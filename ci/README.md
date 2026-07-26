# CI — self-hosted GitHub Actions runners

Four GitHub Actions self-hosted runners run on this host, one per repository. They build and push
the `ghcr.io/malishn22/*` images that the `homelab-apps` stacks then pull.

This directory documents them. The runner installations themselves live outside the repo (they
contain credentials and a few hundred MB of vendored binaries each) and are not tracked here.

## Inventory

| Directory | Repository | systemd unit |
|---|---|---|
| `~/actions-runner` | `malishn22/calimali-backend` | `actions.runner.malishn22-calimali-backend.mali-debian.service` |
| `~/actions-runner-ghms` | `malishn22/ghms-dev` | `actions.runner.malishn22-ghms-dev.mali-debian.service` |
| `~/actions-runner-spotify-archiver` | `malishn22/spotify-archiver` | `actions.runner.malishn22-spotify-archiver.mali-debian.service` |
| `~/runners/spotify-archiver-web` | `malishn22/spotify-archiver-web` | `actions.runner.malishn22-spotify-archiver-web.mali-debian.service` |

All four are **repository-level** runners (not organisation-level), all registered under the
`malishn22` account, and all share the runner name `mali-debian` — the name is only unique within
a repository, so the collision is harmless.

They run as **system** systemd units (not `--user`) executing `<runnerdir>/runsvc.sh` as user
`mali`, with `KillMode=process` so an in-flight job is not killed when the unit stops. Unit files
are in `/etc/systemd/system/`.

Labels are **not** stored on disk. These are v2-flow runners, so GitHub keeps labels server-side
and the local `.runner` file has no `labels` key. Workflows target them with the default
`runs-on: self-hosted`.

> The directory layout is inconsistent: three runners sit at `~/actions-runner*` and the fourth at
> `~/runners/<name>/`, a newer convention adopted in May 2026 and never applied retroactively.
> Harmless, but noted so it reads as a choice rather than an oversight. Unifying it means editing
> each unit's `ExecStart` path and running `systemctl daemon-reload`.

## Operating

```bash
# State of all four
for u in calimali-backend ghms-dev spotify-archiver spotify-archiver-web; do
  printf '%-22s %s\n' "$u" "$(systemctl is-active actions.runner.malishn22-$u.mali-debian.service)"
done

# Restart one
sudo systemctl restart actions.runner.malishn22-ghms-dev.mali-debian.service

# Live logs (the runner's own listener, not the job)
journalctl -u actions.runner.malishn22-ghms-dev.mali-debian.service -f
```

Per-job logs are not in the journal — they are files under each runner's `_diag/`:
`Runner_*.log` for the listener, `Worker_*.log` for individual jobs. The most recent `Worker_*`
timestamp is a good proxy for when that repo last ran CI.

**Nothing rotates `_diag`.** Each runner accumulates ~40 MB of 8.1 MB capped log files. Trim by age
when it bothers you; no service depends on them.

## Resource cost

Each runner directory is ~2.3 GB and each idle listener holds ~800–950 MB resident — roughly
9 GB of disk and 3.5 GB of RAM for four runners doing nothing. The disk is on `/home`
(399 G, ~9 % used), so it is untidy rather than urgent.

The pressure that *does* matter is `/var`: a 12 G LVM volume holding `/var/lib/docker`, sitting
around 75 %. CI is a contributor — every push builds and pulls `:latest` images, and the old layers
accumulate. That is what `../scripts/docker-cleanup.sh` exists to bound.

### Reclaiming space

The runner self-updates but never cleans up after itself. Per directory:

```bash
cd ~/actions-runner            # repeat for each runner directory
readlink bin                   # confirm this says bin.2.335.1 BEFORE the next line

rm actions-runner-linux-x64-*.tar.gz   # original install archives, ~215 MB each
rm -rf bin.2.334.0 externals.2.334.0   # superseded by the symlinked current version, ~670 MB
rm -rf _work/_update                   # self-update staging, ~673 MB
```

That takes each directory from ~2.3 GB to roughly 700 MB. `_work/<repo>/` is the actual job
checkout and must stay — though for three of the four it is empty, since those repos check out
fresh per run.

### Removing a runner

Never `rm -rf` a runner directory. GitHub keeps the registration server-side, leaving a ghost
runner that jobs can queue against forever. Deregister properly:

```bash
sudo ./svc.sh uninstall     # remove the systemd unit
./config.sh remove          # deregister from GitHub (needs a repo-scoped token)
```

All four repositories are active. A runner whose `_work` checkout looks stale means "no recent
push to that repo", not "abandoned" — do not treat quiet as dead.

## The weekly prune

```
0 4 * * 0  ~/homelab/infra/scripts/docker-cleanup.sh >> ~/homelab/infra/scripts/docker-cleanup.log 2>&1
```

In the `mali` user crontab. Prunes images, build cache, and stopped containers older than 168h,
printing `df -h /var` before and after.

**This host records no cron `CMD` lines in the journal**, so `docker-cleanup.log` is the only
evidence the job ran, and the only way to tell "the prune ran and `/var` is still 75 %" (meaning the
prune is no longer sufficient) from "the prune never ran". Deleting the log breaks nothing — the
script recreates it on the next run via `>>` — but it does blind you until the following Sunday.

To keep it bounded, `/etc/logrotate.d/docker-cleanup`:

```
~/homelab/infra/scripts/docker-cleanup.log {
    monthly
    rotate 6
    missingok
    notifempty
    copytruncate
}
```

## Security notes

- `.credentials` and `.credentials_rsaparams` in each runner directory hold the registration
  keypair. Never read, copy, or commit them.
- Each `.path` file bakes in the `PATH` captured at `config.sh` time — all four currently lead with
  a now-stale editor-server `remote-cli` directory. Harmless, but it means the runner's `PATH` is
  not the login shell's `PATH`; a workflow that depends on a tool installed later may not find it.
- Self-hosted runners execute workflow code directly on this host with the `mali` user's
  privileges, including Docker socket access. That is acceptable for private repositories only —
  never enable one of these for a public repo accepting outside pull requests.
