# Enhanced run-ansible.sh Quick Reference

## 🚀 Common Workflows

### Initial Deployment
```bash
# Full deployment (all VMs)
./run-ansible.sh deploy

# Check all services are healthy
./run-ansible.sh health

# View all service URLs
./run-ansible.sh urls
```

### Partial Deployments
```bash
# Deploy only the application (3 VMs)
./run-ansible.sh deploy-app

# Deploy only monitoring stack
./run-ansible.sh deploy-observability

# Deploy only Prometheus
./run-ansible.sh deploy-prometheus

# Deploy only Grafana
./run-ansible.sh deploy-grafana
```

### Managing Specific VMs
```bash
# View logs from specific app VM
./run-ansible.sh logs-app 1        # app-vm-1
./run-ansible.sh logs-app 2        # app-vm-2
./run-ansible.sh logs-app 3        # app-vm-3

# View logs from all app VMs
./run-ansible.sh logs-app all

# Restart specific app VM
./run-ansible.sh restart-app 1     # app-vm-1
./run-ansible.sh restart-app 2     # app-vm-2
```

### Health Monitoring
```bash
# Check all services
./run-ansible.sh health

# Check only applications
./run-ansible.sh health-app

# Check only monitoring stack
./run-ansible.sh health-monitoring
```

### Service Management
```bash
# View status of all services
./run-ansible.sh status

# Show all Docker containers
./run-ansible.sh ps

# Restart services
./run-ansible.sh restart-app all
./run-ansible.sh restart-prometheus
./run-ansible.sh restart-grafana
```

### Logs and Debugging
```bash
# Application logs
./run-ansible.sh logs-app 1        # Specific VM
./run-ansible.sh logs-app all      # All VMs

# Monitoring logs
./run-ansible.sh logs-prometheus
./run-ansible.sh logs-grafana

# Run custom commands
./run-ansible.sh command 'docker ps'
./run-ansible.sh command 'df -h'
```

## 📋 Complete Command Reference

### Connectivity
| Command | Description |
|---------|-------------|
| `./run-ansible.sh ping` | Test all VMs |
| `./run-ansible.sh ping-app` | Test app VMs only |
| `./run-ansible.sh ping-monitoring` | Test monitoring VMs only |

### Deployment
| Command | Description |
|---------|-------------|
| `./run-ansible.sh deploy` | Full deployment |
| `./run-ansible.sh deploy-app` | App VMs only |
| `./run-ansible.sh deploy-prometheus` | Prometheus only |
| `./run-ansible.sh deploy-grafana` | Grafana only |
| `./run-ansible.sh deploy-observability` | Prometheus + Grafana |

### Logs
| Command | Description |
|---------|-------------|
| `./run-ansible.sh logs-app [1\|2\|3\|all]` | Application logs |
| `./run-ansible.sh logs-prometheus` | Prometheus logs |
| `./run-ansible.sh logs-grafana` | Grafana logs |

### Restart Services
| Command | Description |
|---------|-------------|
| `./run-ansible.sh restart-app [1\|2\|3\|all]` | Restart application |
| `./run-ansible.sh restart-prometheus` | Restart Prometheus |
| `./run-ansible.sh restart-grafana` | Restart Grafana |

### Health & Status
| Command | Description |
|---------|-------------|
| `./run-ansible.sh health` | Check all services |
| `./run-ansible.sh health-app` | Check applications |
| `./run-ansible.sh health-monitoring` | Check monitoring |
| `./run-ansible.sh status` | Service status overview |
| `./run-ansible.sh ps` | Docker containers |
| `./run-ansible.sh urls` | All service URLs |

### Utilities
| Command | Description |
|---------|-------------|
| `./run-ansible.sh facts` | Gather system facts |
| `./run-ansible.sh command 'CMD'` | Run command on all VMs |
| `./run-ansible.sh playbook FILE.yml` | Run custom playbook |

## 💡 Usage Examples

### Troubleshooting Failed Deployment
```bash
# Check what's running
./run-ansible.sh status

# Check health
./run-ansible.sh health

# View logs from problematic VM
./run-ansible.sh logs-app 2

# Restart the service
./run-ansible.sh restart-app 2

# Check health again
./run-ansible.sh health-app
```

### Rolling Update Pattern
```bash
# Update one app VM at a time
./run-ansible.sh restart-app 1
./run-ansible.sh health-app       # Verify

./run-ansible.sh restart-app 2
./run-ansible.sh health-app       # Verify

./run-ansible.sh restart-app 3
./run-ansible.sh health-app       # Verify
```

### Monitoring Stack Maintenance
```bash
# Check monitoring status
./run-ansible.sh health-monitoring

# View Prometheus logs
./run-ansible.sh logs-prometheus

# Restart if needed
./run-ansible.sh restart-prometheus

# Verify
./run-ansible.sh health-monitoring
```

### Quick Inspection
```bash
# Get all service URLs
./run-ansible.sh urls

# Check what's running
./run-ansible.sh ps

# Full health check
./run-ansible.sh health
```

## 🎯 Comparison with Old Script

### Old Script
```bash
./run-ansible.sh ping
./run-ansible.sh playbook playbook.yml
./run-ansible.sh command 'docker ps'
```

### New Script (Same functionality + More)
```bash
# Same commands still work
./run-ansible.sh ping
./run-ansible.sh playbook playbook.yml
./run-ansible.sh command 'docker ps'

# Plus new targeted commands
./run-ansible.sh deploy-app
./run-ansible.sh logs-app 1
./run-ansible.sh restart-prometheus
./run-ansible.sh health
./run-ansible.sh urls
```

## 🔧 Advanced Usage

### Targeted Ansible Commands
```bash
# Run command only on app VMs
ansible app_nodes -i ansible/inventory.ini -a "docker ps"

# Run command only on monitoring VMs
ansible 'prometheus_node:grafana_node' -i ansible/inventory.ini -a "docker ps"

# Run on specific VM
ansible app-vm-1 -i ansible/inventory.ini -a "docker logs python-app-instance"
```

### Custom Playbook Runs
```bash
# Run with specific tags
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags phase1

# Limit to specific hosts
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --limit app-vm-1

# Run with extra variables
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -e "git_branch=develop"
```

## 📊 Output Examples

### health command
```
══════════════════════════════════════════
Checking Health of All Services
══════════════════════════════════════════

Application VMs:
✓ app-vm-1 is healthy
✓ app-vm-2 is healthy
✓ app-vm-3 is healthy

Monitoring Stack:
✓ Prometheus is healthy
✓ Grafana is healthy
```

### urls command
```
══════════════════════════════════════════
Service URLs
══════════════════════════════════════════

📦 Application VMs:
   App VM 1: http://192.168.56.11:5000
   Health:   http://192.168.56.11:5000/api/health
   App VM 2: http://192.168.56.12:5000
   Health:   http://192.168.56.12:5000/api/health
   App VM 3: http://192.168.56.13:5000
   Health:   http://192.168.56.13:5000/api/health

📊 Monitoring Stack:
   Prometheus: http://192.168.56.14:9090
   Grafana:    http://192.168.56.15:3000 (admin/admin)

🔍 Node Exporters (Port 9100):
   app-vm-1: http://192.168.56.11:9100
   app-vm-2: http://192.168.56.12:9100
   ...
```

## 🎨 Color Coding

The script uses colors to make output clearer:
- 🔵 **Blue**: Informational messages
- 🟢 **Green**: Success/healthy status
- 🔴 **Red**: Errors/unhealthy status
- 🟡 **Yellow**: Warnings/section headers
- 🔆 **Cyan**: Section dividers
- 🟣 **Magenta**: Main action titles

## ⚡ Tips

1. **Always check health after deployment**:
   ```bash
   ./run-ansible.sh deploy && ./run-ansible.sh health
   ```

2. **Use `urls` to quickly access services**:
   ```bash
   ./run-ansible.sh urls
   ```

3. **Monitor specific VMs during troubleshooting**:
   ```bash
   ./run-ansible.sh logs-app 2 && ./run-ansible.sh restart-app 2
   ```

4. **Check status before making changes**:
   ```bash
   ./run-ansible.sh status && ./run-ansible.sh deploy-app
   ```
