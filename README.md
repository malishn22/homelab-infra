# Homelab Infra

This repository contains the infrastructure configurations for my personal homelab.

I’m using this project both as my real environment I rely on and as a playground to learn and practice DevOps concepts like **containerization**, **IAC**, **reverse proxying** and **monitoring** 

> 💡 Application code (web apps, APIs, etc.) lives in the repository below.
> This repo is only for infrastructure, configs, and automation.

[![Apps Repo](https://img.shields.io/badge/Repo-homelab--apps-blue?style=for-the-badge)](https://https://github.com/malishn22/homelab-apps)

---

## 🔧 Tech Stack

- **Host:** Beelink SER5 MAX Mini PC (Debian based, 24/7 server)
- **Containerization:** Docker + Docker Compose
- **Reverse Proxy:** Nginx
- **Monitoring:** Prometheus, Node Exporter, Grafana
- **Bookmark Manager:** Linkding (behind Nginx)
- **Config Management Style:** env files + versioned configs

---

## 🏗️ Repository Structure

```text
infra/
├─ linkding/                   # Linkding bookmark manager stack
│  ├─ .env.example             # Example env vars for Linkding
│  ├─ docker-compose.yml       # Linkding container
│  └─ README.md
│
├─ monitoring/                 # Monitoring stack (Prometheus, Grafana, Exporters)
│  ├─ prometheus/              # Prometheus config
│  │  ├─ prometheus.yml
│  ├─ docker-compose.yml       # Prometheus, Node Exporter, Nginx Exporter, Grafana
│
├─ nginx/                      # Global reverse proxy for all services
│  ├─ conf.d/                  # Nginx Config
│  │  ├─ linkding.conf         # Reverse Proxy for Linkding
│  │  └─ stub_status.conf      # stub_status for metrics in Monitoring
│  ├─ .env.example             # Example env vars for Nginx
│  ├─ docker-compose.yml       # Nginx Reverse Proxy Container
│  └─ README.md
│
└─ .gitignore
