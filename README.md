# Homelab Infra

This repository contains the infrastructure configurations for my personal homelab.

I’m using this project both as my real environment I rely on and as a playground to learn and practice DevOps concepts like **containerization**, **IAC**, **reverse proxying** and **monitoring** 

> 💡 Application code (web apps, APIs, etc.) lives in the repository below.
> This repo is only for infrastructure, configs, and automation.

[![Apps Repo](https://img.shields.io/badge/Repo-homelab--apps-blue?style=for-the-badge)](https://github.com/malishn22/homelab-apps)

---

## 🔧 Tech Stack

- **Host:** Beelink SER5 MAX Mini PC (Debian based, 24/7 server)
- **Containerization:** Docker + Docker Compose
- **Reverse Proxy:** Nginx
- **Monitoring:** Prometheus, Node Exporter, cAdvisor, Grafana
- **Logs:** Loki + Promtail (queried from Grafana)
- **CI:** four self-hosted GitHub Actions runners — see `ci/README.md`
- **Bookmark Manager:** Linkding (behind Nginx)
- **Media Server:** Jellyfin (behind Nginx, VAAPI hardware transcoding)
- **Config Management Style:** env files + versioned configs

---

## 🏗️ Repository Structure

```text
infra/
├─ jellyfin/                   # Jellyfin media server stack
│  ├─ .env.example             # Example env vars for Jellyfin
│  ├─ docker-compose.yml       # Jellyfin container (iGPU passthrough, media mounted :ro)
│  └─ README.md
│
├─ linkding/                   # Linkding bookmark manager stack
│  ├─ .env.example             # Example env vars for Linkding
│  ├─ docker-compose.yml       # Linkding container
│  └─ README.md
│
├─ monitoring/                 # Metrics + logs stack
│  ├─ prometheus/              # Prometheus config
│  │  └─ prometheus.yml
│  ├─ loki/                    # Loki log store config
│  │  └─ loki-config.yml
│  ├─ promtail/                # Log shipper config
│  │  └─ promtail-config.yml
│  ├─ grafana/                 # Provisioned datasources + dashboards (JSON in git)
│  │  ├─ provisioning/
│  │  └─ dashboards/
│  ├─ .env.example             # Grafana admin vars
│  ├─ docker-compose.yml       # Prometheus, Grafana, Node/Nginx Exporter, cAdvisor, Loki, Promtail
│  └─ README.md
│
├─ nginx/                      # Global reverse proxy for all services
│  ├─ conf.d/                  # Nginx Config
│  │  ├─ calimali-api.conf     # Reverse Proxy for the Calimali API
│  │  ├─ jellyfin.conf         # Reverse Proxy for Jellyfin
│  │  ├─ linkding.conf         # Reverse Proxy for Linkding
│  │  ├─ minecraft.conf        # Reverse Proxy for the Minecraft web UI
│  │  └─ stub_status.conf      # stub_status for metrics in Monitoring
│  ├─ .env.example             # Example env vars for Nginx
│  ├─ docker-compose.yml       # Nginx Reverse Proxy Container
│  └─ README.md
│
├─ scripts/                    # Host maintenance scripts
│  └─ docker-cleanup.sh        # Weekly prune (cron) so /var doesn't fill from CI churn
│
├─ ci/                         # Self-hosted GitHub Actions runners
│  └─ README.md                # Inventory, systemd units, maintenance, security notes
│
├─ .github/workflows/          # CI
│  └─ nginx-ci.yml             # Validates compose + nginx configs on nginx/** changes
│
├─ CLAUDE.md                   # Repo conventions and traps (for AI assistants and humans)
└─ .gitignore
```
