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

### **cAdvisor**
Exposes per-container resource metrics (CPU, memory, filesystem, network) for everything running
on the host, so container-level usage can be separated from host-level usage.

- Reads the Docker socket and `/` (read-only) to discover containers.
- Scraped internally; no host port published.

---

### **Loki + Promtail**
The log half of the stack, alongside the metrics half.

- **Promtail** tails container logs on the host and ships them to Loki.
- **Loki** indexes them by label and is queried from Grafana as a second datasource, so a spike on
  a metrics dashboard can be pivoted straight to the logs from that moment.
- Both are scraped/served internally; neither publishes a host port.

---

### **Spotify Archiver**
The archiver's web backend exposes app-level metrics (sync runs, run status, durations).

- Scraped over the `homelab` network as job `spotify-archiver`, target `backend:8000`.
- Dashboard: `grafana/dashboards/spotify-archiver.json`.

> ⚠️ That target is the literal container name `backend`, which is generic. Do not name another
> container `backend` on the `homelab` network or Prometheus will scrape the wrong one.

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
├─ loki/
│  └─ loki-config.yml          # Loki storage + retention config
├─ promtail/
│  └─ promtail-config.yml      # Which container logs to tail and how to label them
├─ grafana/
│  ├─ provisioning/
│  │  ├─ datasources/          # Auto-registered Prometheus + Loki datasources
│  │  └─ dashboards/           # Dashboard provider config
│  └─ dashboards/
│     ├─ ghms.json             # GHMS dashboard definition
│     └─ spotify-archiver.json # Spotify Archiver sync-health dashboard
├─ .env.example                # Grafana admin vars (copy to .env)
└─ docker-compose.yml          # Prometheus, Grafana, Node Exporter, Nginx Exporter,
                               # cAdvisor, Loki, Promtail
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
- cAdvisor  
- Loki  
- Promtail  

They all join the `homelab` Docker network automatically.

---

## 🌐 Accessing the Services

| Service           | URL (LAN)                           |
|-------------------|-------------------------------------|
| Prometheus        | `http://<TARGET_IP>:9091`           |
| Grafana           | `http://<TARGET_IP>:3000`           |
| Node Exporter     | Scraped internally only             |
| Nginx Exporter    | Scraped internally only             |
| cAdvisor          | Scraped internally only             |
| Loki              | Queried by Grafana only             |
| Promtail          | No UI — ships logs to Loki          |

---

## 🔧 Requirements

- `homelab` Docker network must exist:

  ```bash
  docker network create homelab
  ```

---

## ✏️ Updating a Dashboard

Provisioned dashboards load from `grafana/dashboards/*.json` on startup — the
JSON file is the source of truth, **not** the Grafana database. UI edits save to
the DB and are **overwritten on the next restart/redeploy**. To make a change
stick:

1. Edit the dashboard in the Grafana UI until it looks right.
2. Dashboard settings (gear) → **JSON Model** → copy the whole model.
3. Paste it over the matching file, e.g. `grafana/dashboards/ghms.json`.
4. Check the panel datasource `uid` is still `prometheus-homelab` (a fresh
   export can revert it to a random value — fix it back, or a clean deploy
   shows "datasource not found").
5. Commit, push, then redeploy / restart Grafana.

---

## 📝 Notes

- This stack is fully isolated from Linkding.
- Prometheus scrapes everything via container DNS, not via host ports.
- The Grafana datasource and dashboards are auto-provisioned from
  `grafana/provisioning/`. Edit dashboards in git (the JSON), not in the UI —
  provisioned dashboards are marked non-editable in place.
- Copy `.env.example` to `.env` and set a Grafana admin password before first
  run; compose will refuse to start without `GF_SECURITY_ADMIN_PASSWORD`.
- **Prometheus retention is capped deliberately.** The retention flags are enforced against data
  that already exists, not just future growth, and the stricter of time/size wins — so lowering
  either below current usage deletes the oldest blocks on the next start. Doing this once cost
  ~15 days of metrics. Snapshot `monitoring_prometheus-data` before changing them.
- `prometheus-data`, `grafana_storage`, and `loki-data` are **named** volumes, so they live under
  `/var/lib/docker` on a 12 G LVM volume. This stack is the usual reason `/var` fills.
