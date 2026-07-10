#!/usr/bin/env bash
# Weekly Docker cleanup — reclaims unused images + build cache so /var (a 12G LVM
# volume holding /var/lib/docker) doesn't fill from CI image churn on this host.
# The `until=168h` filter only removes images/cache older than 7 days, so it never
# deletes an image a running container still needs or one from a recent deploy.
# Scheduled via cron (Sun 04:00). Safe to run by hand any time.
set -euo pipefail
echo "[docker-cleanup] $(date -Is) — before:"; df -h /var | tail -1
docker image prune -af   --filter "until=168h"
docker builder prune -af --filter "until=168h"
docker container prune -f
echo "[docker-cleanup] after:"; df -h /var | tail -1
