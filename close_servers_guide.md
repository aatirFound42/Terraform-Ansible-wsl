# Shutdown Guide - Stop All Services & VMs

## 🛑 Quick Shutdown (Recommended)

### Option 1: Stop All Containers on All VMs
```bash
# Stop all Docker containers gracefully on all VMs
./run-ansible.sh command 'docker stop $(docker ps -aq)'

# Verify all stopped
./run-ansible.sh command 'docker ps'
```

### Option 2: Stop Specific Services
```bash
# Stop applications
./run-ansible.sh command 'docker stop python-app-instance' --limit app_nodes

# Stop Prometheus
./run-ansible.sh command 'docker stop prometheus' --limit prometheus_node

# Stop Grafana
./run-ansible.sh command 'docker stop grafana' --limit grafana_node

# Stop all node exporters
./run-ansible.sh command 'docker stop node-exporter'
```

---

## 🔌 Shutdown VMs

### If using Vagrant:
```bash
# Graceful shutdown (saves state, quick restart)
vagrant suspend

# Or power off completely (no state saved)
vagrant halt

# To destroy completely (free up all resources)
vagrant destroy -f
```

### If using Terraform/Libvirt:
```bash
cd terraform  # or wherever your terraform files are

# Stop VMs (preserves them)
terraform apply -auto-approve -var="vm_count=0"

# Or destroy completely
terraform destroy -auto-approve
```

### Manual virsh commands:
```bash
# List all running VMs
virsh list

# Shutdown gracefully (one by one)
virsh shutdown node-0
virsh shutdown node-1
virsh shutdown node-2
virsh shutdown node-3
virsh shutdown node-4

# Or force shutdown if needed
virsh destroy node-0
virsh destroy node-1
virsh destroy node-2
virsh destroy node-3
virsh destroy node-4
```

---

## ♻️ Restart Tomorrow

### If you used `vagrant suspend`:
```bash
vagrant resume
./run-ansible.sh health  # Verify everything is running
```

### If you used `vagrant halt`:
```bash
vagrant up
./run-ansible.sh health  # Verify everything is running
```

### If you destroyed everything:
```bash
# Recreate VMs
vagrant up  # or terraform apply

# Redeploy everything
./run-ansible.sh deploy
./run-ansible.sh health
```

### If Docker containers stopped but VMs still running:
```bash
# Just restart the containers (much faster!)
./run-ansible.sh command 'docker start $(docker ps -aq)'

# Or redeploy specific services
./run-ansible.sh deploy-app
./run-ansible.sh deploy-observability
```

---

## 📋 Complete Shutdown Checklist

```bash
# 1. Stop all Docker containers
./run-ansible.sh command 'docker stop $(docker ps -aq)'

# 2. Verify all stopped
./run-ansible.sh command 'docker ps'

# 3. Shutdown VMs
vagrant halt  # or vagrant suspend for faster restart

# 4. (Optional) Check VM status
vagrant status
# or
virsh list --all
```

---

## 🎯 Best Practice for Tomorrow

**Recommended approach** for quick restart tomorrow:

1. **Today (stopping)**:
   ```bash
   # Just suspend VMs (fastest restart tomorrow)
   vagrant suspend
   ```

2. **Tomorrow (starting)**:
   ```bash
   # Resume VMs (very fast)
   vagrant resume
   
   # Verify services are running
   ./run-ansible.sh health
   
   # If any services are down, restart them
   ./run-ansible.sh command 'docker start $(docker ps -aq)'
   ```

**Alternative** if you want clean shutdown:

1. **Today**:
   ```bash
   # Stop services first
   ./run-ansible.sh command 'docker stop $(docker ps -aq)'
   
   # Then halt VMs
   vagrant halt
   ```

2. **Tomorrow**:
   ```bash
   # Start VMs
   vagrant up
   
   # Restart all services (they should auto-start with restart_policy: unless-stopped)
   ./run-ansible.sh health
   
   # If needed, manually start
   ./run-ansible.sh command 'docker start $(docker ps -aq)'
   ```

---

## 🔍 Check What's Running

```bash
# Check VM status
vagrant status

# Check which containers are running
./run-ansible.sh ps

# Check service health
./run-ansible.sh health
```

---

## ⚠️ Important Notes

1. **Docker `restart_policy: unless-stopped`** means containers will auto-start when VMs boot up (unless you manually stopped them)

2. **Suspend vs Halt**:
   - `suspend`: Saves RAM to disk, fastest restart (like laptop sleep)
   - `halt`: Clean shutdown, slower restart (like full shutdown)

3. **If using `terraform destroy`**: You'll need to redeploy everything tomorrow

4. **Data persistence**: 
   - Prometheus data is in volumes, will persist across restarts
   - Grafana settings will persist
   - Application will restart fresh (stateless)
