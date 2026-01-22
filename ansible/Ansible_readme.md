# Multi-VM Deployment Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Deployment Architecture                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Application VMs (3):                                        │
│  ├─ app-vm-1 (192.168.56.11) - Python App + Node Exporter  │
│  ├─ app-vm-2 (192.168.56.12) - Python App + Node Exporter  │
│  └─ app-vm-3 (192.168.56.13) - Python App + Node Exporter  │
│                                                              │
│  Monitoring VMs (2):                                         │
│  ├─ prometheus-vm (192.168.56.14) - Prometheus + Node Exp.  │
│  └─ grafana-vm (192.168.56.15) - Grafana + Node Exporter    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
ansible/
├── ansible.cfg
├── inventory.ini              # Multi-VM inventory
├── playbook.yml              # Multi-VM deployment playbook
├── requirements.yml
└── files/
    ├── prometheus.yml.j2     # Dynamic Prometheus config (template)
    └── grafana/
        └── datasources/
            └── datasources.yml.j2  # Dynamic Grafana datasource (template)
```

## Prerequisites

1. **Update your inventory.ini** with actual IP addresses:
   ```ini
   [app_nodes]
   app-vm-1 ansible_host=YOUR_IP_1
   app-vm-2 ansible_host=YOUR_IP_2
   app-vm-3 ansible_host=YOUR_IP_3

   [prometheus_node]
   prometheus-vm ansible_host=YOUR_IP_4

   [grafana_node]
   grafana-vm ansible_host=YOUR_IP_5
   ```

2. **Convert static configs to templates**:
   ```bash
   # Rename files to templates
   mv files/prometheus.yml files/prometheus.yml.j2
   mv files/grafana/datasources/datasources.yml files/grafana/datasources/datasources.yml.j2
   ```

3. **Install Ansible collections**:
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

## Deployment Commands

### Full Deployment (All VMs)
```bash
ansible-playbook playbook.yml
```

### Deploy Specific Components

**1. Setup all VMs (Docker + Node Exporter)**
```bash
ansible-playbook playbook.yml --tags setup
```

**2. Deploy Application Only**
```bash
ansible-playbook playbook.yml --limit app_nodes
```

**3. Deploy Prometheus Only**
```bash
ansible-playbook playbook.yml --limit prometheus_node
```

**4. Deploy Grafana Only**
```bash
ansible-playbook playbook.yml --limit grafana_node
```

**5. Deploy to specific VM**
```bash
ansible-playbook playbook.yml --limit app-vm-1
```

### Rolling Updates

**Update application on one VM at a time**
```bash
ansible-playbook playbook.yml --limit app_nodes --serial 1
```

**Update specific app VM**
```bash
ansible-playbook playbook.yml --limit app-vm-2
```

## Verification Commands

### Check All Services
```bash
# Check all VMs
ansible all_vms -m shell -a "docker ps"

# Check application VMs
ansible app_nodes -m shell -a "curl -s http://localhost:5000/api/health"

# Check Prometheus
ansible prometheus_node -m shell -a "curl -s http://localhost:9090/-/healthy"

# Check Grafana
ansible grafana_node -m shell -a "curl -s http://localhost:3000/api/health"

# Check Node Exporters
ansible all_vms -m shell -a "curl -s http://localhost:9100/metrics | head -5"
```

### Access URLs
After deployment, access:
- **App VMs**: `http://<app-vm-ip>:5000`
- **Prometheus**: `http://<prometheus-vm-ip>:9090`
- **Grafana**: `http://<grafana-vm-ip>:3000` (admin/admin)
- **Node Exporters**: `http://<any-vm-ip>:9100`

## Troubleshooting

### View logs from specific VM
```bash
# Application logs
ansible app-vm-1 -m shell -a "docker logs python-app-instance --tail 50"

# Prometheus logs
ansible prometheus_node -m shell -a "docker logs prometheus --tail 50"

# Grafana logs
ansible grafana_node -m shell -a "docker logs grafana --tail 50"
```

### Restart services
```bash
# Restart app on specific VM
ansible app-vm-1 -m shell -a "docker restart python-app-instance"

# Restart Prometheus
ansible prometheus_node -m shell -a "docker restart prometheus"

# Restart Grafana
ansible grafana_node -m shell -a "docker restart grafana"
```

### Check connectivity
```bash
# Ping all VMs
ansible all_vms -m ping

# Check if VMs can reach each other
ansible app-vm-1 -m shell -a "curl -s http://<prometheus-vm-ip>:9090/-/healthy"
```

## Load Balancing (Optional)

To add a load balancer in front of the 3 app VMs, you can:

1. **Use HAProxy/Nginx on a separate VM**
2. **Update inventory to include load balancer**
3. **Configure load balancer to distribute traffic across app VMs**

Example HAProxy configuration:
```
frontend http_front
   bind *:80
   default_backend http_back

backend http_back
   balance roundrobin
   server app1 192.168.56.11:5000 check
   server app2 192.168.56.12:5000 check
   server app3 192.168.56.13:5000 check
```

## Key Changes from Single-VM Deployment

1. **Inventory**: Organized into groups (app_nodes, prometheus_node, grafana_node)
2. **Multiple Plays**: Separate plays for each component type
3. **Dynamic Configuration**: Templates (.j2) generate configs with actual IPs
4. **Node Exporter**: Deployed on ALL VMs in the first play
5. **No Docker Compose**: Each service runs as standalone container
6. **Inter-VM Communication**: Services reference each other by IP addresses

## Benefits of Multi-VM Architecture

- **Scalability**: Easy to add more app VMs
- **Isolation**: Monitoring stack separate from application
- **High Availability**: Multiple app instances
- **Resource Optimization**: Dedicated resources per service type
- **Independent Updates**: Update components without affecting others
