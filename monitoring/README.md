# 📡 Monitoring Stack

This folder contains the full monitoring setup for the homelab, including **Prometheus**, **Grafana**, **Node Exporter**, and **Nginx Exporter for Prometheus**.  
All components run inside Docker and share the `homelab` Docker network so Prometheus can scrape them.

---

## 🧩 Components

### **Prometheus**
Collects metrics from exporters and services.

- Uses configuration from: `prometheus/prometheus.yml`

---

### **Node Exporter**
Gathers system-level host metrics (CPU, RAM, disk, network) so far, planned to integrate more useful metrics once i learn more.

- Runs with rootfs access via `--path.rootfs=/host`.

---

### **Nginx Prometheus Exporter**
Scrapes metrics from the main Nginx reverse proxy (For test purposes).

- Requires `stub_status.conf` enabled inside the nginx container.

---

### **GHMS Backend**
The GHMS (Minecraft manager) backend exposes app-level metrics at `/metrics`
(fleet size, lifecycle events, backups, modpack cache, HTTP stats).

- Scraped over the `homelab` network at `ghms-backend:8000` (job `ghms`).

---

### **Grafana**
Visualizes data coming from Prometheus.

- Accessible in browser on port `3000` by default.
- Admin credentials come from `.env` (`GF_SECURITY_ADMIN_USER` /
  `GF_SECURITY_ADMIN_PASSWORD`) — see `.env.example`.
- The Prometheus datasource **and** dashboards are auto-provisioned from
  `grafana/provisioning/` on startup, so a fresh deploy comes up preconfigured.
  The GHMS dashboard lives in `grafana/dashboards/ghms.json`.

---

## 📁 Folder Structure

```text
monitoring/
├─ prometheus/
│  └─ prometheus.yml           # Prometheus scrape config
├─ grafana/
│  ├─ provisioning/
│  │  ├─ datasources/          # Auto-registered Prometheus datasource
│  │  └─ dashboards/           # Dashboard provider config
│  └─ dashboards/
│     └─ ghms.json             # GHMS dashboard definition
├─ .env.example                # Grafana admin vars (copy to .env)
└─ docker-compose.yml          # Prometheus, Grafana, Node Exporter, Nginx Exporter
```

---

## 🚀 Running the Monitoring Stack

Run inside this folder:

```bash
docker compose up -d
```

This will start:

- Prometheus  
- Grafana  
- Node Exporter  
- Nginx Prometheus Exporter  

They all join the `homelab` Docker network automatically.

---

## 🌐 Accessing the Services

| Service           | URL (LAN)                           |
|-------------------|-------------------------------------|
| Prometheus        | `http://<TARGET_IP>:9091`           |
| Grafana           | `http://<TARGET_IP>:3000`           |
| Node Exporter     | Scraped internally only             |
| Nginx Exporter    | Scraped internally only             |

---

## 🔧 Requirements

- `homelab` Docker network must exist:

  ```bash
  docker network create homelab
  ```

---

## 📝 Notes

- This stack is fully isolated from Linkding.
- Prometheus scrapes everything via container DNS, not via host ports.
- The Grafana datasource and dashboards are auto-provisioned from
  `grafana/provisioning/`. Edit dashboards in git (the JSON), not in the UI —
  provisioned dashboards are marked non-editable in place.
- Copy `.env.example` to `.env` and set a Grafana admin password before first
  run; compose will refuse to start without `GF_SECURITY_ADMIN_PASSWORD`.
