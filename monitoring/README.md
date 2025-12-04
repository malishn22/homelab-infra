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

### **Grafana**
Visualizes data coming from Prometheus.

- Accessible in browser on port `3000` by default.

---

## 📁 Folder Structure

```text
monitoring/
├─ prometheus/
│  └─ prometheus.yml           # Prometheus scrape config
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
- Grafana dashboards are not auto-provisioned yet
