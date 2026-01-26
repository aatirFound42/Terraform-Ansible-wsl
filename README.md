# Kubernetes HA Multi-Master Cluster with CI/CD Pipeline

A complete Infrastructure as Code (IaC) solution for deploying a production-ready High Availability Kubernetes cluster with integrated CI/CD pipeline, monitoring, and automated testing.

## 🏗️ Architecture Overview

**Infrastructure (9 VMs):**
- **1 Load Balancer** - HAProxy for API server HA (192.168.56.9)
- **2 Master Nodes** - Control plane with etcd (192.168.56.10-11)
- **6 Worker Nodes** - Application workload nodes (192.168.56.12-17)

**Applications & Services:**
- **Frontend** - React/Vue web application (NodePort 30300)
- **Backend** - Flask REST API (NodePort 30500)
- **Prometheus** - Metrics collection (NodePort 30090)
- **Grafana** - Visualization dashboards (NodePort 30030)
- **Selenium Grid** - Automated browser testing (NodePort 30444)
- **Pushgateway** - Batch job metrics (NodePort 30091)
- **Node Exporter** - System metrics (DaemonSet)

---

## 📋 Prerequisites

### System Requirements
- **OS**: WSL2 on Windows (Ubuntu 20.04+ recommended) or Linux
- **RAM**: 16GB minimum (20GB+ recommended)
- **CPU**: 8+ cores
- **Disk**: 50GB free space
- **Network**: VirtualBox Host-Only network adapter

### Required Software
```bash
# VirtualBox
VirtualBox 6.1+ or 7.0+

# Vagrant
vagrant --version  # 2.3.0+

# Terraform
terraform --version  # 1.0.0+

# Ansible
ansible --version  # 2.9.0+

# kubectl (optional, for local management)
kubectl version --client
```

---

## 🚀 Quick Start Guide

### 1. Initial Setup (WSL Only)

If running on WSL, configure the environment first:

```bash
# Setup WSL environment for Vagrant
./setup-wsl.sh

# Reload your shell
source ~/.bashrc
```

### 2. Infrastructure Deployment

Use `run-terraform.sh` to manage the VM infrastructure:

```bash
# Initialize Terraform (first time only)
./run-terraform.sh init

# Preview infrastructure changes
./run-terraform.sh plan

# Create all 9 VMs
./run-terraform.sh apply

# Check cluster status
./run-terraform.sh status

# SSH into a specific node
./run-terraform.sh ssh 0  # Master node-0
./run-terraform.sh ssh 2  # Worker node-2
```

**Infrastructure Creation Time:** ~10-15 minutes

### 3. Kubernetes Cluster Deployment

Use `run-ansible-k8s.sh` to deploy Kubernetes and applications:

```bash
# Full deployment (all components)
./run-ansible-k8s.sh deploy

# OR deploy in phases for better control
./run-ansible-k8s.sh phase1  # LB + Primary Master + CNI
./run-ansible-k8s.sh phase2  # Join Secondary Master
./run-ansible-k8s.sh phase3  # Join Worker Nodes
./run-ansible-k8s.sh phase4  # Deploy Applications
```

**Deployment Time:** ~15-20 minutes

### 4. Verify Deployment

```bash
# Check cluster nodes
./run-ansible-k8s.sh nodes

# Check all pods
./run-ansible-k8s.sh pods

# Check services
./run-ansible-k8s.sh services

# View all service URLs
./run-ansible-k8s.sh urls

# Health check
./run-ansible-k8s.sh health
```

---

## 🎯 run-terraform.sh - Infrastructure Management

Manages the VM infrastructure using Terraform and Vagrant.

### Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `init` | Initialize Terraform workspace | `./run-terraform.sh init` |
| `plan` | Preview infrastructure changes | `./run-terraform.sh plan` |
| `apply` | Create all VMs | `./run-terraform.sh apply` |
| `destroy` | Destroy all VMs | `./run-terraform.sh destroy` |
| `status` | Show VM status and connectivity | `./run-terraform.sh status` |
| `ssh N` | SSH into VM N (0-8) | `./run-terraform.sh ssh 0` |
| `info` | Display cluster information | `./run-terraform.sh info` |
| `clean` | Clean all Terraform/Vagrant files | `./run-terraform.sh clean` |

### VM Mapping

| VM Number | Hostname | IP Address | Role | Resources |
|-----------|----------|------------|------|-----------|
| N/A | lb-0 | 192.168.56.9 | Load Balancer | 1 CPU, 512MB |
| 0 | node-0 | 192.168.56.10 | Primary Master | 2 CPU, 2GB |
| 1 | node-1 | 192.168.56.11 | Secondary Master | 2 CPU, 2GB |
| 2-7 | node-2 to node-7 | 192.168.56.12-17 | Workers | 2 CPU, 1.5GB |

### Examples

```bash
# Create infrastructure
./run-terraform.sh apply

# Check if all VMs are accessible
./run-terraform.sh status

# SSH to primary master
./run-terraform.sh ssh 0

# SSH to first worker
./run-terraform.sh ssh 2

# Completely remove infrastructure
./run-terraform.sh destroy
```

---

## 🔧 run-ansible-k8s.sh - Kubernetes & Application Management

Manages Kubernetes cluster deployment, configuration, and applications.

### Deployment Commands

#### Full Deployment
```bash
# Deploy everything (LB + K8s + Apps)
./run-ansible-k8s.sh deploy

# Deploy only cluster (skip apps)
./run-ansible-k8s.sh deploy-cluster
```

#### Phased Deployment
```bash
# Phase 1: Load Balancer + Primary Master + CNI
./run-ansible-k8s.sh phase1

# Phase 2: Join Secondary Master
./run-ansible-k8s.sh phase2

# Phase 3: Join all Worker Nodes
./run-ansible-k8s.sh phase3

# Phase 4: Deploy Applications
./run-ansible-k8s.sh phase4
```

#### Granular Deployment
```bash
# Individual components
./run-ansible-k8s.sh deploy-lb          # Load balancer only
./run-ansible-k8s.sh deploy-primary     # Primary master only
./run-ansible-k8s.sh deploy-secondary   # Secondary masters
./run-ansible-k8s.sh deploy-workers     # Worker nodes
./run-ansible-k8s.sh deploy-apps        # Applications only
```

### Application Management

#### Frontend/Backend Operations
```bash
# Deploy/Update
./run-ansible-k8s.sh deploy-frontend    # Frontend only
./run-ansible-k8s.sh deploy-backend     # Backend only
./run-ansible-k8s.sh deploy-fullstack   # Both frontend & backend

# Scale
./run-ansible-k8s.sh scale-frontend 3   # Scale to 3 replicas
./run-ansible-k8s.sh scale-backend 5    # Scale to 5 replicas

# Restart
./run-ansible-k8s.sh restart-frontend
./run-ansible-k8s.sh restart-backend

# Logs
./run-ansible-k8s.sh logs-frontend
./run-ansible-k8s.sh logs-backend

# Status
./run-ansible-k8s.sh status-fullstack
```

#### Monitoring Stack
```bash
# Deploy/Restart individual components
./run-ansible-k8s.sh deploy-grafana
./run-ansible-k8s.sh restart-prometheus
./run-ansible-k8s.sh restart-grafana
```

#### Selenium Grid
```bash
# Scale Selenium nodes
./run-ansible-k8s.sh scale-selenium 5

# Restart Selenium
./run-ansible-k8s.sh restart-selenium

# Run manual test
./run-ansible-k8s.sh selenium-test

# View test metrics
./run-ansible-k8s.sh selenium-metrics
```

### Cluster Operations

#### Status & Monitoring
```bash
./run-ansible-k8s.sh nodes          # Show cluster nodes
./run-ansible-k8s.sh pods           # Show pods
./run-ansible-k8s.sh services       # Show services
./run-ansible-k8s.sh deployments    # Show deployments
./run-ansible-k8s.sh health         # Health check
./run-ansible-k8s.sh status         # Full status
./run-ansible-k8s.sh urls           # All service URLs
./run-ansible-k8s.sh metrics        # Resource usage
```

#### Load Balancer Management
```bash
./run-ansible-k8s.sh lb-status      # HAProxy status
./run-ansible-k8s.sh lb-stats       # Statistics URL
./run-ansible-k8s.sh lb-config      # View configuration
./run-ansible-k8s.sh lb-restart     # Restart HAProxy
```

#### Kubectl Commands
```bash
# Run any kubectl command on primary master
./run-ansible-k8s.sh kubectl get pods -A
./run-ansible-k8s.sh kubectl describe pod <pod-name> -n monitoring

# Built-in commands
./run-ansible-k8s.sh describe-pod <pod-name>
./run-ansible-k8s.sh logs-pod <pod-name>
```

#### Troubleshooting
```bash
./run-ansible-k8s.sh debug-cluster     # Full cluster diagnostic
./run-ansible-k8s.sh debug-apiserver   # API server issues
./run-ansible-k8s.sh logs-node node-0  # Node kubelet logs
./run-ansible-k8s.sh logs-lb           # HAProxy logs
./run-ansible-k8s.sh top-nodes         # Node resource usage
./run-ansible-k8s.sh top-pods          # Pod resource usage
```

#### Node Maintenance
```bash
./run-ansible-k8s.sh drain node-2      # Drain node for maintenance
./run-ansible-k8s.sh uncordon node-2   # Mark node schedulable
```

#### HA Testing
```bash
./run-ansible-k8s.sh ha-test           # Test HA failover
```

---

## 📊 Accessing Services

### After Successful Deployment

All services are accessible via NodePort on any master or worker node IP (192.168.56.10-17):

```bash
# Get all URLs
./run-ansible-k8s.sh urls
```

### Service URLs (Default)

**Applications:**
- Frontend: http://192.168.56.10:30300
- Backend: http://192.168.56.10:30500
- Backend Health: http://192.168.56.10:30500/api/health

**Monitoring:**
- Prometheus: http://192.168.56.10:30090
- Grafana: http://192.168.56.10:30030 (admin/admin)
- Pushgateway: http://192.168.56.10:30091

**Testing:**
- Selenium Hub: http://192.168.56.10:30444

**Infrastructure:**
- HAProxy Stats: http://192.168.56.9:8404 (admin/admin123)
- Kubernetes API: https://192.168.56.9:6443

---

## 🔄 CI/CD Pipeline Workflow

### Automated Testing Pipeline

The cluster includes an automated Selenium testing pipeline that runs every 2 minutes:

1. **Selenium CronJob** triggers every 2 minutes
2. **Chrome nodes** execute browser tests against frontend/backend
3. **Test results** pushed to Pushgateway
4. **Prometheus** scrapes metrics from Pushgateway
5. **Grafana** visualizes test results and trends

### Manual Pipeline Trigger

```bash
# Trigger manual test
./run-ansible-k8s.sh selenium-test

# View test results
./run-ansible-k8s.sh selenium-metrics

# Check test job logs
./run-ansible-k8s.sh kubectl logs -l job-name=selenium-test-manual-* -n monitoring
```

### Monitoring the Pipeline

**Prometheus Metrics:**
- `selenium_success` - Test pass/fail (1/0)
- `selenium_latency_seconds` - Page load time

**View in Prometheus:**
```bash
# Open Prometheus
curl http://192.168.56.10:30090

# Query: selenium_success{instance="http://cicd-backend:5000"}
# Query: selenium_latency_seconds
```

**Grafana Dashboards:**
1. Access Grafana: http://192.168.56.10:30030
2. Login: admin/admin
3. Create dashboard with Prometheus data source
4. Add panels for:
   - Test success rate over time
   - Average latency trends
   - Backend/Frontend availability

---

## 🛠️ Common Workflows

### Development Workflow

```bash
# 1. Update application code and build new image
# 2. Push to container registry

# 3. Deploy updated backend
./run-ansible-k8s.sh deploy-backend

# 4. Deploy updated frontend
./run-ansible-k8s.sh deploy-frontend

# 5. Check deployment status
./run-ansible-k8s.sh status-fullstack

# 6. View logs if issues
./run-ansible-k8s.sh logs-backend
./run-ansible-k8s.sh logs-frontend
```

### Scaling Workflow

```bash
# Scale for increased load
./run-ansible-k8s.sh scale-backend 5
./run-ansible-k8s.sh scale-frontend 3
./run-ansible-k8s.sh scale-selenium 10

# Monitor resource usage
./run-ansible-k8s.sh metrics

# Check pod distribution
./run-ansible-k8s.sh pods
```

### Troubleshooting Workflow

```bash
# 1. Check overall health
./run-ansible-k8s.sh health

# 2. Identify failing components
./run-ansible-k8s.sh pods

# 3. Describe problematic pod
./run-ansible-k8s.sh describe-pod <pod-name>

# 4. Check logs
./run-ansible-k8s.sh logs-pod <pod-name>

# 5. Full cluster diagnostic
./run-ansible-k8s.sh debug-cluster
```

### Maintenance Workflow

```bash
# 1. Drain node for maintenance
./run-ansible-k8s.sh drain node-2

# 2. Verify pods moved
./run-ansible-k8s.sh pods

# 3. Perform maintenance (SSH to node)
./run-terraform.sh ssh 2

# 4. Mark node schedulable again
./run-ansible-k8s.sh uncordon node-2
```

---

## 📁 Project Structure

```
.
├── run-terraform.sh              # Infrastructure management script
├── run-ansible-k8s.sh           # Kubernetes & app management script
├── setup-wsl.sh                 # WSL environment setup
│
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                  # VM definitions
│   ├── variables.tf             # Configuration variables
│   └── outputs.tf               # Output values
│
├── ansible/                     # Configuration Management
│   ├── playbook-k8s.yml        # Main Kubernetes playbook
│   ├── inventory.ini            # Auto-generated from Terraform
│   │
│   └── files/k8s/              # Kubernetes manifests
│       ├── namespace.yml
│       ├── backend-deployment.yml
│       ├── frontend-deployment.yml
│       ├── prometheus-deployment.yml
│       ├── grafana-deployment.yml
│       ├── selenium-hub-deployment.yml
│       ├── selenium-chrome-deployment.yml
│       ├── selenium-test-cronjob.yml
│       ├── pushgateway-deployment.yml
│       └── node-exporter-daemonset.yml
│
└── README.md                    # This file
```

---

## 🔒 Security Notes

### Default Credentials (Change in Production!)

- **Grafana**: admin/admin
- **HAProxy Stats**: admin/admin123
- **Vagrant SSH**: vagrant/vagrant
- **Kubernetes**: Certificates in `/etc/kubernetes/`

### Network Security

- All services use NodePort (30000-32767 range)
- Internal cluster network: 10.244.0.0/16 (Calico)
- Service network: 10.96.0.0/12
- Host network: 192.168.56.0/24

### Best Practices for Production

1. Change all default passwords
2. Enable RBAC and configure proper roles
3. Use Ingress with TLS instead of NodePort
4. Implement Network Policies
5. Enable Pod Security Standards
6. Use secrets management (Sealed Secrets, Vault)
7. Regular backups of etcd

---

## 🐛 Troubleshooting Guide

### VMs Not Starting

```bash
# Check Vagrant status
cd terraform
vagrant global-status

# Check VirtualBox VMs
VBoxManage list vms
VBoxManage list runningvms

# Restart a specific VM
vagrant up node-0 --provision
```

### SSH Connection Issues

```bash
# Verify SSH key permissions
ls -la ~/.vagrant.d/insecure_private_key
chmod 600 ~/.vagrant.d/insecure_private_key

# Clear known hosts
ssh-keygen -R 192.168.56.10

# Test manual SSH
ssh -i ~/.vagrant.d/insecure_private_key vagrant@192.168.56.10
```

### Ansible Connectivity Issues

```bash
# Test Ansible ping
cd ansible
ansible all -m ping

# Test specific host
ansible node-0 -m ping -vvv
```

### Kubernetes Issues

```bash
# Check control plane pods
./run-ansible-k8s.sh kubectl get pods -n kube-system

# Check node status
./run-ansible-k8s.sh kubectl get nodes -o wide

# Full diagnostic
./run-ansible-k8s.sh debug-cluster
```

### Application Not Accessible

```bash
# Check if pods are running
./run-ansible-k8s.sh pods

# Check services
./run-ansible-k8s.sh services

# Check pod logs
./run-ansible-k8s.sh logs-backend
./run-ansible-k8s.sh logs-frontend

# Restart deployment
./run-ansible-k8s.sh restart-backend
```

### Prometheus Frontend Down

If Prometheus shows `cicd-frontend` as down with "unsupported Content-Type":

```bash
# This is expected - frontend doesn't expose metrics
# Edit Prometheus config to remove frontend scraping
./run-ansible-k8s.sh kubectl edit configmap prometheus-config -n monitoring

# Remove the cicd-frontend scrape job
# Then restart Prometheus
./run-ansible-k8s.sh restart-prometheus
```

---

## 📈 Monitoring & Observability

### Prometheus Metrics

**Available Metrics:**
- `up` - Service availability
- `selenium_success` - Test results
- `selenium_latency_seconds` - Response times
- `node_*` - System metrics (CPU, memory, disk, network)
- `kubelet_*` - Kubernetes metrics
- `container_*` - Container metrics

### Sample Prometheus Queries

```promql
# Backend uptime percentage (last 24h)
avg_over_time(up{job="cicd-backend"}[24h]) * 100

# Average response time (last hour)
avg_over_time(selenium_latency_seconds[1h])

# Test success rate
sum(selenium_success) / count(selenium_success) * 100

# Node CPU usage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Grafana Dashboard Setup

1. Access Grafana: http://192.168.56.10:30030
2. Login: admin/admin
3. Add Prometheus data source (already configured)
4. Import or create dashboards for:
   - Cluster overview
   - Application performance
   - Test results
   - Node metrics

---

## 🔄 Cleanup & Reset

### Partial Cleanup

```bash
# Delete only applications
./run-ansible-k8s.sh delete-frontend
./run-ansible-k8s.sh delete-backend

# Redeploy specific components
./run-ansible-k8s.sh phase4
```

### Full Cleanup

```bash
# Destroy all infrastructure
./run-terraform.sh destroy

# Clean all files
./run-terraform.sh clean

# Remove Vagrant boxes (optional)
vagrant box list
vagrant box remove ubuntu/focal64
```

### Fresh Deployment

```bash
# Complete reset and redeploy
./run-terraform.sh clean
./run-terraform.sh apply
./run-ansible-k8s.sh deploy
```

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

- Kubernetes community
- Calico Project
- Prometheus & Grafana teams
- Selenium Project
- Ansible & Terraform communities

---

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Check troubleshooting guide above
- Review Ansible/Terraform logs

---

**Happy Clustering! 🚀**
