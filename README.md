# Kubernetes HA Multi-Master Cluster with CI/CD Pipeline

A complete Infrastructure as Code (IaC) solution for deploying a production-ready High Availability Kubernetes cluster with integrated CI/CD pipeline, monitoring, and automated testing on VirtualBox using Terraform, Vagrant, and Ansible.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.9+-EE0000?logo=ansible)](https://www.ansible.com/)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Accessing Services](#-accessing-services)
- [Management Commands](#-management-commands)
- [Troubleshooting](#-troubleshooting)
- [Advanced Usage](#-advanced-usage)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This project automates the deployment of a **production-grade High Availability Kubernetes cluster** with:

- **9 Virtual Machines** (1 Load Balancer + 2 Masters + 5 Workers)
- **HAProxy Load Balancer** for API server high availability
- **Multi-master control plane** with etcd clustering
- **Calico CNI** for pod networking
- **Integrated monitoring** with Prometheus and Grafana
- **Automated CI/CD testing** with Selenium Grid
- **Sample applications** (Frontend + Backend)

### Key Features

✅ **High Availability**: Multi-master setup with HAProxy load balancing  
✅ **Automated Deployment**: Complete infrastructure provisioning with Terraform and Ansible  
✅ **Production-Ready**: Monitoring, logging, and health checks included  
✅ **CI/CD Pipeline**: Automated browser testing with Selenium  
✅ **Easy Management**: Comprehensive CLI tools for cluster operations  
✅ **WSL Compatible**: Seamless integration with VirtualBox on Windows  

---

## 🏗️ Architecture

### Infrastructure Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer (lb-0)                     │
│                   HAProxy - 192.168.56.12                    │
│                    (API HA & Stats)                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼────────┐           ┌────────▼───────┐
│  Master Node 0 │           │  Master Node 1 │
│ 192.168.56.10  │           │ 192.168.56.11  │
│ (Primary)      │◄─────────►│ (Secondary)    │
│ 2 CPU, 2GB RAM │           │ 2 CPU, 2GB RAM │
└────────────────┘           └────────────────┘
        │                             │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴─────────────────────────┐
        │                                        │
┌───────▼────────┐  ┌────────────┐  ┌──────────▼─────┐
│  Worker Node 0 │  │     ...    │  │  Worker Node 4 │
│ 192.168.56.12  │  │  3 more    │  │ 192.168.56.17  │
│ 1 CPU, 1.5GB   │  │  workers   │  │ 1 CPU, 1.5GB   │
└────────────────┘  └────────────┘  └────────────────┘
```

### Applications & Services

| Service | Type | Port | Description |
|---------|------|------|-------------|
| **Frontend** | Web App | 30300 | React/Vue application |
| **Backend** | REST API | 30500 | Flask backend service |
| **Prometheus** | Monitoring | 30090 | Metrics collection |
| **Grafana** | Dashboard | 30030 | Visualization (admin/admin) |
| **Selenium Hub** | Testing | 30444 | Browser automation |
| **Pushgateway** | Metrics | 30091 | Batch job metrics |
| **HAProxy Stats** | LB Stats | 8404 | Load balancer stats (admin/admin123) |

### Resource Allocation

- **Total VMs**: 8 (1 LB + 2 Masters + 5 Workers)
- **Total CPU**: 10 vCPU (1 LB + 4 Masters + 5 Workers)
- **Total RAM**: 13 GB (1.5 LB + 4 Masters + 7.5 Workers)
- **Network**: VirtualBox Host-Only (192.168.56.0/24)

---

## 📋 Prerequisites

### Required Software

Before starting, ensure you have the following installed:

#### 1. **Windows Subsystem for Linux (WSL2)**
   - Windows 10/11 with WSL2 enabled
   - Ubuntu 20.04+ recommended
   
   ```powershell
   # Install WSL2 (PowerShell as Administrator)
   wsl --install
   ```

#### 2. **VirtualBox** (Windows)
   - Version 6.1+ or 7.0+
   - Download from: https://www.virtualbox.org/wiki/Downloads
   - ⚠️ **Important**: Install on Windows, NOT in WSL

#### 3. **Git** (WSL)
   ```bash
   # Install in WSL
   sudo apt update
   sudo apt install -y git
   ```

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 16 GB | 20+ GB |
| **CPU** | 8 cores | 12+ cores |
| **Disk** | 50 GB free | 100+ GB free |
| **OS** | Windows 10/11 | Windows 11 |
| **WSL** | WSL2 | WSL2 Ubuntu 22.04 |

### Network Requirements

- VirtualBox Host-Only network adapter configured
- No firewall blocking ports 30000-32767
- Internet access for downloading container images

---

## 🚀 Quick Start

### Installation Steps

Follow these steps to get your cluster up and running:

#### **Step 1: Clone the Repository**

```bash
git clone https://github.com/aatirFound42/Terraform-Ansible-wsl.git
cd Terraform-Ansible-wsl
```

#### **Step 2: Make Scripts Executable**

```bash
chmod +x setup-wsl.sh
chmod +x run-terraform.sh
chmod +x run-ansible-k8s.sh
```

#### **Step 3: Setup WSL Environment**

This configures Terraform, Vagrant, Ansible, and VirtualBox integration:

```bash
./setup-wsl.sh
```

**Expected output:**
```
================================================
Setup Complete!
================================================

Next Steps:
  1. Run: source ~/.bashrc
     Or restart your WSL terminal
```

**Apply the changes:**
```bash
source ~/.bashrc
```

#### **Step 4: Initialize Terraform**

```bash
./run-terraform.sh init
```

**Expected output:**
```
✓ Terraform initialized
```

#### **Step 5: Create Infrastructure**

This creates all 9 VMs (takes ~10-15 minutes):

```bash
./run-terraform.sh apply
```

**Expected output:**
```
================================================
VMs Created Successfully!
================================================

✓ All nodes accessible! (2 masters, 6 workers)
```

#### **Step 6: Verify Infrastructure (Optional)**

```bash
./run-terraform.sh status
```

This shows VM status and SSH connectivity.

#### **Step 7: Test Ansible Connectivity (Optional)**

```bash
./run-ansible-k8s.sh ping
```

**Expected output:**
```
✓ All nodes responding
```

#### **Step 8: Deploy Kubernetes Cluster**

This deploys the entire HA cluster with all applications (~15-20 minutes):

```bash
./run-ansible-k8s.sh deploy
```

**⚠️ Important Notes:**
- If the deployment gets stuck for 5-10 minutes on any task, press `Ctrl+C`
- Then re-run the deploy command - Ansible is idempotent and will continue from where it stopped
- Common sticking points: pulling container images (depends on internet speed)

```bash
# If stuck, stop and retry:
# Press Ctrl+C
./run-ansible-k8s.sh deploy
```

#### **Step 9: Verify Cluster Health (Optional)**

```bash
./run-ansible-k8s.sh health
```

**Expected output:**
```
✓ HAProxy accessible
✓ All masters ready
✓ All workers ready
✓ All pods running
```

#### **Step 10: Get Service URLs**

```bash
./run-ansible-k8s.sh urls
```

**Expected output:**
```
🔧 Infrastructure:
   HAProxy Stats: http://192.168.56.12:8404
   
📦 Application:
   Frontend:      http://192.168.56.10:30300
   Backend:       http://192.168.56.10:30500
   
📊 Monitoring:
   Prometheus:    http://192.168.56.10:30090
   Grafana:       http://192.168.56.10:30030
   
🧪 Testing:
   Selenium Hub:  http://192.168.56.10:30444
```

### 🎉 Deployment Complete!

Your HA Kubernetes cluster is now running. Open the URLs in your browser to access the services.

---

## 📁 Project Structure

```
Terraform-Ansible-wsl/
│
├── README.md                      # This file
├── LICENSE                        # MIT License
│
├── setup-wsl.sh                   # WSL environment setup script
├── run-terraform.sh               # Infrastructure management script
├── run-ansible-k8s.sh             # Kubernetes deployment & management script
│
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                    # VM definitions (9 VMs)
│   ├── variables.tf               # Configuration variables
│   ├── outputs.tf                 # Output values (IPs, etc.)
│   └── Vagrantfile                # Vagrant VM configuration
│
├── ansible/                       # Configuration Management
│   ├── playbook-k8s.yml           # Main Kubernetes deployment playbook
│   ├── inventory.ini              # Auto-generated from Terraform
│   │
│   └── files/                     # Static files
│       └── k8s/                   # Kubernetes manifests
│           ├── namespace.yml
│           ├── backend-deployment.yml
│           ├── frontend-deployment.yml
│           ├── prometheus-deployment.yml
│           ├── grafana-deployment.yml
│           ├── selenium-hub-deployment.yml
│           ├── selenium-chrome-deployment.yml
│           ├── selenium-test-cronjob.yml
│           ├── pushgateway-deployment.yml
│           └── node-exporter-daemonset.yml
│
└── .gitignore                     # Git ignore file
```

---

## 🌐 Accessing Services

After deployment, all services are accessible via NodePort on any master or worker node IP.

### Service URLs

Replace `192.168.56.10` with any master (10-11) or worker (12-17) node IP:

#### **Infrastructure**
```
HAProxy Stats:     http://192.168.56.12:8404
  Username: admin
  Password: admin123

Kubernetes API:    https://192.168.56.12:6443
  (via Load Balancer)
```

#### **Applications**
```
Frontend:          http://192.168.56.10:30300
Backend:           http://192.168.56.10:30500
Backend Health:    http://192.168.56.10:30500/api/health
```

#### **Monitoring**
```
Prometheus:        http://192.168.56.10:30090
Grafana:           http://192.168.56.10:30030
  Username: admin
  Password: admin

Pushgateway:       http://192.168.56.10:30091
```

#### **Testing**
```
Selenium Hub:      http://192.168.56.10:30444
```

### Quick Access Commands

```bash
# Get all service URLs
./run-ansible-k8s.sh urls

# Check service health
./run-ansible-k8s.sh health

# View cluster status
./run-ansible-k8s.sh status
```

---

## 🛠️ Management Commands

### Infrastructure Management (`run-terraform.sh`)

#### Basic Commands

```bash
# Initialize Terraform
./run-terraform.sh init

# Create all VMs
./run-terraform.sh apply

# Destroy all VMs
./run-terraform.sh destroy

# Show VM status
./run-terraform.sh status

# List all nodes
./run-terraform.sh list

# Show cluster info
./run-terraform.sh info

# Clean all files
./run-terraform.sh clean
```

#### SSH Access

```bash
# SSH to master-1 (node-0)
./run-terraform.sh ssh 0

# SSH to master-2 (node-1)
./run-terraform.sh ssh 1

# SSH to worker-1 (node-2)
./run-terraform.sh ssh 2

# SSH to worker-6 (node-7)
./run-terraform.sh ssh 7
```

#### Node Management

```bash
# Destroy specific node
./run-terraform.sh destroy-node 3

# Destroy multiple nodes
./run-terraform.sh destroy-nodes 2 3 4

# Destroy all masters
./run-terraform.sh destroy-masters

# Destroy all workers
./run-terraform.sh destroy-workers

# Restart a node
./run-terraform.sh restart-node 0
```

#### VM State Control

```bash
# Suspend (save state)
./run-terraform.sh suspend 2          # Suspend worker-1
./run-terraform.sh suspend-all        # Suspend all nodes
./run-terraform.sh suspend-workers    # Suspend all workers

# Resume
./run-terraform.sh resume 2           # Resume worker-1
./run-terraform.sh resume-all         # Resume all nodes

# Halt (power off)
./run-terraform.sh halt 3             # Halt worker-2
./run-terraform.sh halt-workers       # Halt all workers

# Start
./run-terraform.sh up 3               # Start worker-2
./run-terraform.sh up-all             # Start all nodes

# Reload (restart)
./run-terraform.sh reload 0           # Reload master-1
```

### Kubernetes Management (`run-ansible-k8s.sh`)

#### Deployment Commands

```bash
# Full deployment (all phases)
./run-ansible-k8s.sh deploy

# Phased deployment
./run-ansible-k8s.sh phase1           # LB + Primary Master + CNI
./run-ansible-k8s.sh phase2           # Join Secondary Masters
./run-ansible-k8s.sh phase3           # Join Worker Nodes
./run-ansible-k8s.sh phase4           # Deploy Applications

# Granular deployment
./run-ansible-k8s.sh deploy-lb        # Load balancer only
./run-ansible-k8s.sh deploy-primary   # Primary master only
./run-ansible-k8s.sh deploy-apps      # Applications only
```

#### Application Management

```bash
# Frontend/Backend
./run-ansible-k8s.sh deploy-frontend      # Deploy frontend
./run-ansible-k8s.sh deploy-backend       # Deploy backend
./run-ansible-k8s.sh deploy-fullstack     # Deploy both

./run-ansible-k8s.sh scale-frontend 3     # Scale to 3 replicas
./run-ansible-k8s.sh scale-backend 5      # Scale to 5 replicas

./run-ansible-k8s.sh restart-frontend     # Restart frontend
./run-ansible-k8s.sh restart-backend      # Restart backend

./run-ansible-k8s.sh logs-frontend        # View frontend logs
./run-ansible-k8s.sh logs-backend         # View backend logs

./run-ansible-k8s.sh status-fullstack     # Check status
```

#### Monitoring Stack

```bash
# Deploy/Restart
./run-ansible-k8s.sh deploy-grafana       # Deploy Grafana
./run-ansible-k8s.sh restart-prometheus   # Restart Prometheus
./run-ansible-k8s.sh restart-grafana      # Restart Grafana
```

#### Cluster Operations

```bash
# Status & Health
./run-ansible-k8s.sh nodes                # Show nodes
./run-ansible-k8s.sh pods                 # Show pods
./run-ansible-k8s.sh services             # Show services
./run-ansible-k8s.sh health               # Health check
./run-ansible-k8s.sh status               # Full status
./run-ansible-k8s.sh urls                 # Service URLs

# Kubectl commands
./run-ansible-k8s.sh kubectl get pods -A
./run-ansible-k8s.sh kubectl describe pod <pod-name> -n monitoring

# Load Balancer
./run-ansible-k8s.sh lb-status            # HAProxy status
./run-ansible-k8s.sh lb-stats             # Statistics URL
./run-ansible-k8s.sh lb-restart           # Restart HAProxy

# Testing
./run-ansible-k8s.sh selenium-test        # Run manual test
./run-ansible-k8s.sh selenium-metrics     # View metrics
```

---

## 🐛 Troubleshooting

### ⚠️ Most Common Issue: VirtualBox /dev/null Error

If you see this error when running `./run-terraform.sh apply`:

```
VBoxManage.exe: error: RawFile#0 failed to create the raw output file /dev/null (VERR_PATH_NOT_FOUND)
```

**Quick Fix (Run these commands):**

```bash
# Method 1: Use the fix script
chmod +x fix-vbox-devnull.sh
./fix-vbox-devnull.sh
source ~/.bashrc

# Method 2: Manual fix
echo 'export VBOX_MSI_INSTALL_PATH="/mnt/c/Program Files/Oracle/VirtualBox"' >> ~/.bashrc
source ~/.bashrc

# Then clean up and retry
./run-terraform.sh destroy
./run-terraform.sh apply
```

**Why this happens:**
VirtualBox on Windows tries to use the Linux path `/dev/null` when called from WSL. The `VBOX_MSI_INSTALL_PATH` environment variable tells it to use the Windows equivalent (`NUL`).

---

### Common Issues

#### **Issue 1: VirtualBox /dev/null error**

**Symptoms:**
- Error: `RawFile#0 failed to create the raw output file /dev/null (VERR_PATH_NOT_FOUND)`
- Error code: `E_FAIL (0x80004005)`
- All VMs fail to start

**Root Cause:**
VirtualBox on Windows tries to use Linux path `/dev/null` when called from WSL.

**Solution:**
```bash
# Add environment variable to ~/.bashrc
echo 'export VBOX_MSI_INSTALL_PATH="/mnt/c/Program Files/Oracle/VirtualBox"' >> ~/.bashrc
source ~/.bashrc

# OR re-run setup script (recommended)
./setup-wsl.sh
source ~/.bashrc

# Then retry
./run-terraform.sh destroy  # Clean up failed attempts
./run-terraform.sh apply
```

**Prevention:**
This is already included in the latest `setup-wsl.sh` script. Make sure you've run it.

#### **Issue 2: VMs not starting**

**Symptoms:**
- `vagrant up` fails
- VMs show as "not created"

**Solution:**
```bash
# Check VirtualBox
VBoxManage list vms

# Restart VirtualBox service (Windows)
# Run in PowerShell as Administrator:
Get-Service -Name "VBoxSDS" | Restart-Service

# In WSL, retry
./run-terraform.sh apply
```

#### **Issue 2: Ansible cannot connect to VMs**

**Symptoms:**
- `./run-ansible-k8s.sh ping` fails
- SSH connection timeout

**Solution:**
```bash
# Check VM status
./run-terraform.sh status

# Test manual SSH
./run-terraform.sh ssh 0

# Fix SSH keys
rm -f ~/.ssh/known_hosts
./run-terraform.sh apply  # Re-apply to fix keys
```

#### **Issue 3: Deployment stuck on image pulling**

**Symptoms:**
- Deployment hangs on "Pulling image..."
- Takes more than 10 minutes

**Solution:**
```bash
# Stop deployment
# Press Ctrl+C

# Retry (Ansible will continue)
./run-ansible-k8s.sh deploy

# Or deploy in phases
./run-ansible-k8s.sh phase1
./run-ansible-k8s.sh phase2
./run-ansible-k8s.sh phase3
./run-ansible-k8s.sh phase4
```

#### **Issue 4: Pods not starting**

**Symptoms:**
- Pods stuck in `Pending` or `ImagePullBackOff`

**Solution:**
```bash
# Check pod status
./run-ansible-k8s.sh kubectl get pods -n monitoring

# Describe problematic pod
./run-ansible-k8s.sh describe-pod <pod-name>

# Check node resources
./run-ansible-k8s.sh kubectl get nodes -o wide

# Restart deployment
./run-ansible-k8s.sh restart-backend
```

#### **Issue 5: HAProxy not accessible**

**Symptoms:**
- Cannot access http://192.168.56.9:8404
- API server not responding

**Solution:**
```bash
# Check HAProxy status
./run-ansible-k8s.sh lb-status

# View HAProxy logs
./run-ansible-k8s.sh logs-lb

# Restart HAProxy
./run-ansible-k8s.sh lb-restart

# Re-deploy load balancer
./run-ansible-k8s.sh deploy-lb
```

### Debugging Commands

```bash
# Full cluster diagnostic
./run-ansible-k8s.sh debug-cluster

# Debug API server
./run-ansible-k8s.sh debug-apiserver

# Node logs
./run-ansible-k8s.sh logs-node node-0

# Resource usage
./run-ansible-k8s.sh top-nodes
./run-ansible-k8s.sh top-pods
```

### Reset and Clean

```bash
# Destroy and recreate everything
./run-terraform.sh destroy
./run-terraform.sh clean
./run-terraform.sh apply
./run-ansible-k8s.sh deploy

# Reset specific node
./run-terraform.sh restart-node 0
```

---

## 🔧 Advanced Usage

### CI/CD Pipeline

The cluster includes an automated Selenium testing pipeline:

```bash
# View pipeline status
./run-ansible-k8s.sh test-selenium

# Trigger manual test
./run-ansible-k8s.sh selenium-test

# View test metrics
./run-ansible-k8s.sh selenium-metrics

# Check CronJob
./run-ansible-k8s.sh kubectl get cronjobs -n monitoring
```

**Pipeline Flow:**
1. CronJob triggers every 2 minutes
2. Selenium tests run against frontend/backend
3. Results pushed to Pushgateway
4. Prometheus scrapes metrics
5. Grafana visualizes results

### High Availability Testing

```bash
# Test HA failover
./run-ansible-k8s.sh ha-test

# Simulate master failure
./run-terraform.sh halt 0  # Halt master-1

# Verify cluster still works
./run-ansible-k8s.sh kubectl get nodes

# Restore master
./run-terraform.sh up 0
```

### Scaling Operations

```bash
# Scale application components
./run-ansible-k8s.sh scale-frontend 5
./run-ansible-k8s.sh scale-backend 3
./run-ansible-k8s.sh scale-selenium 10

# Add/remove worker nodes
./run-terraform.sh destroy-node 7    # Remove worker-6
./run-terraform.sh restart-node 7    # Add back worker-6
./run-ansible-k8s.sh deploy-workers  # Join to cluster
```

### Monitoring Setup

```bash
# Access Grafana
# URL: http://192.168.56.10:30030
# Login: admin/admin

# Import Kubernetes dashboards
# Dashboard ID: 315 (Kubernetes cluster monitoring)
# Dashboard ID: 1860 (Node Exporter Full)

# Query Prometheus
# URL: http://192.168.56.10:30090
# Sample query: up{job="cicd-backend"}
```

### Custom Deployments

```bash
# Deploy custom application
./run-ansible-k8s.sh kubectl apply -f your-app.yaml

# Create namespace
./run-ansible-k8s.sh kubectl create namespace custom-app

# Deploy to custom namespace
./run-ansible-k8s.sh kubectl apply -f your-app.yaml -n custom-app
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Test all changes on a clean deployment
- Update documentation for new features
- Follow existing code style and structure
- Add comments for complex logic

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Kubernetes Community** - For the amazing container orchestration platform
- **Calico Project** - For robust pod networking
- **Prometheus & Grafana** - For comprehensive monitoring solutions
- **Selenium Project** - For browser automation testing
- **HashiCorp** - For Terraform and Vagrant
- **Ansible** - For powerful configuration management

---

## 📞 Support & Contact

- **Issues**: [GitHub Issues](https://github.com/aatirFound42/Terraform-Ansible-wsl/issues)
- **Discussions**: [GitHub Discussions](https://github.com/aatirFound42/Terraform-Ansible-wsl/discussions)
- **Author**: [@aatirFound42](https://github.com/aatirFound42)

---

## 📊 Project Stats

- **VMs**: 9 (1 LB + 2 Masters + 6 Workers)
- **Total Resources**: 14 vCPU, 13.5 GB RAM
- **Services**: 8 (Frontend, Backend, Prometheus, Grafana, Selenium Hub, Chrome Nodes, Pushgateway, Node Exporter)
- **Network**: 192.168.56.0/24 (VirtualBox Host-Only)
- **Deployment Time**: ~25-35 minutes (Infrastructure + Kubernetes + Apps)

---

**Happy Clustering! 🚀**

*Built with ❤️ for the DevOps community*
