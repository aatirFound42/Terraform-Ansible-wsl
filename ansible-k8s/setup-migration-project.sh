#!/bin/bash
# setup-migration-project.sh
# This script creates the complete directory structure for the Kubernetes migration

set -e

PROJECT_ROOT="k8s-migration"

echo "🚀 Creating Kubernetes Migration Project Structure..."

# Create main project directory
mkdir -p ${PROJECT_ROOT}
cd ${PROJECT_ROOT}

# ============================================================================
# 1. ANSIBLE DIRECTORY (Pre-Migration & Infrastructure Prep)
# ============================================================================
echo "📁 Creating Ansible directory structure..."

mkdir -p ansible/{inventory,playbooks,group_vars,roles}

# Ansible inventory
cat > ansible/inventory/hosts.ini << 'EOF'
[control_plane]
cp-01 ansible_host=192.168.56.20
cp-02 ansible_host=192.168.56.21
cp-03 ansible_host=192.168.56.22

[workers]
worker-01 ansible_host=192.168.56.30
worker-02 ansible_host=192.168.56.31
worker-03 ansible_host=192.168.56.32
worker-04 ansible_host=192.168.56.33
worker-05 ansible_host=192.168.56.34

[k8s_cluster:children]
control_plane
workers

[all:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=~/ssh-keys/insecure_private_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3
EOF

# Ansible configuration
cat > ansible/ansible.cfg << 'EOF'
[defaults]
inventory = ./inventory/hosts.ini
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_fact_cache
fact_caching_timeout = 3600

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
EOF

# Pre-migration playbook (place the artifact content here)
touch ansible/playbooks/pre-migration-prep.yml

echo "  ✓ Ansible structure created"

# ============================================================================
# 2. KUBESPRAY DIRECTORY (Will be cloned, but we prepare config)
# ============================================================================
echo "📁 Creating Kubespray configuration directory..."

mkdir -p kubespray-config/{inventory,group_vars}

# Kubespray inventory (hosts.yaml)
touch kubespray-config/inventory/hosts.yaml

# Kubespray cluster configuration
mkdir -p kubespray-config/group_vars/k8s_cluster
touch kubespray-config/group_vars/k8s_cluster/k8s-cluster.yml
touch kubespray-config/group_vars/k8s_cluster/addons.yml

cat > kubespray-config/README.md << 'EOF'
# Kubespray Configuration

These files need to be copied into the Kubespray directory after cloning.

## Setup Instructions:

1. Clone Kubespray:
   ```bash
   git clone https://github.com/kubernetes-sigs/kubespray.git
   cd kubespray
   git checkout release-2.24
   ```

2. Create custom inventory:
   ```bash
   cp -r inventory/sample inventory/mycluster
   ```

3. Copy our configurations:
   ```bash
   cp ../kubespray-config/inventory/hosts.yaml inventory/mycluster/hosts.yaml
   cp ../kubespray-config/group_vars/k8s_cluster/k8s-cluster.yml inventory/mycluster/group_vars/k8s_cluster/
   ```

4. Deploy cluster:
   ```bash
   ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b
   ```
EOF

echo "  ✓ Kubespray config structure created"

# ============================================================================
# 3. KUBERNETES MANIFESTS (Organized by component)
# ============================================================================
echo "📁 Creating Kubernetes manifests directory..."

mkdir -p k8s-manifests/{applications,storage,networking,monitoring,testing}

# --- Applications (Flask API) ---
mkdir -p k8s-manifests/applications/flask-api
touch k8s-manifests/applications/flask-api/{namespace.yaml,deployment.yaml,service.yaml,ingress.yaml,hpa.yaml,pdb.yaml}

cat > k8s-manifests/applications/flask-api/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: flask-app

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
EOF

# --- Storage (Longhorn) ---
mkdir -p k8s-manifests/storage/longhorn
touch k8s-manifests/storage/longhorn/values.yaml

cat > k8s-manifests/storage/longhorn/install.sh << 'EOF'
#!/bin/bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  -f values.yaml
EOF
chmod +x k8s-manifests/storage/longhorn/install.sh

# --- Networking (MetalLB + Ingress) ---
mkdir -p k8s-manifests/networking/{metallb,ingress-nginx}

# MetalLB
touch k8s-manifests/networking/metallb/{ipaddresspool.yaml,l2advertisement.yaml}

cat > k8s-manifests/networking/metallb/install.sh << 'EOF'
#!/bin/bash
echo "Installing MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB pods to be ready..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

echo "Applying MetalLB configuration..."
kubectl apply -f ipaddresspool.yaml
kubectl apply -f l2advertisement.yaml

echo "✅ MetalLB installed successfully"
EOF
chmod +x k8s-manifests/networking/metallb/install.sh

# Ingress
touch k8s-manifests/networking/ingress-nginx/values.yaml

cat > k8s-manifests/networking/ingress-nginx/install.sh << 'EOF'
#!/bin/bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f values.yaml
EOF
chmod +x k8s-manifests/networking/ingress-nginx/install.sh

# --- Monitoring (Prometheus Stack) ---
mkdir -p k8s-manifests/monitoring/prometheus-stack
touch k8s-manifests/monitoring/prometheus-stack/values.yaml

cat > k8s-manifests/monitoring/prometheus-stack/install.sh << 'EOF'
#!/bin/bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f values.yaml
EOF
chmod +x k8s-manifests/monitoring/prometheus-stack/install.sh

mkdir -p k8s-manifests/monitoring/ingress
touch k8s-manifests/monitoring/ingress/{prometheus-ingress.yaml,grafana-ingress.yaml}

# --- Testing (Selenium) ---
mkdir -p k8s-manifests/testing/selenium
touch k8s-manifests/testing/selenium/{namespace.yaml,pushgateway.yaml,selenium-chrome.yaml,test-runner.yaml}

cat > k8s-manifests/testing/selenium/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: testing

resources:
  - namespace.yaml
  - pushgateway.yaml
  - selenium-chrome.yaml
  - test-runner.yaml
EOF

echo "  ✓ Kubernetes manifests structure created"

# ============================================================================
# 4. HELM CHARTS (Custom values for all Helm deployments)
# ============================================================================
echo "📁 Creating Helm values directory..."

mkdir -p helm-values/{longhorn,ingress-nginx,prometheus-stack}

# Create symlinks to keep things DRY
ln -s ../../k8s-manifests/storage/longhorn/values.yaml helm-values/longhorn/values.yaml 2>/dev/null || true
ln -s ../../k8s-manifests/networking/ingress-nginx/values.yaml helm-values/ingress-nginx/values.yaml 2>/dev/null || true
ln -s ../../k8s-manifests/monitoring/prometheus-stack/values.yaml helm-values/prometheus-stack/values.yaml 2>/dev/null || true

echo "  ✓ Helm values structure created"

# ============================================================================
# 5. SCRIPTS (Automation & Helper Scripts)
# ============================================================================
echo "📁 Creating scripts directory..."

mkdir -p scripts/{deployment,validation,backup,migration}

# Deployment script
cat > scripts/deployment/deploy-all.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Kubernetes Deployment..."

# Phase 1: Storage
echo "📦 Phase 1: Installing Longhorn Storage..."
cd ../../k8s-manifests/storage/longhorn
./install.sh
cd -

# Phase 2: Networking
echo "🌐 Phase 2: Installing MetalLB..."
cd ../../k8s-manifests/networking/metallb
./install.sh
cd -

echo "🌐 Phase 2: Installing Ingress Controller..."
cd ../../k8s-manifests/networking/ingress-nginx
./install.sh
cd -

# Phase 3: Applications
echo "🐍 Phase 3: Deploying Flask API..."
kubectl apply -k ../../k8s-manifests/applications/flask-api/

# Phase 4: Monitoring
echo "📊 Phase 4: Installing Prometheus Stack..."
cd ../../k8s-manifests/monitoring/prometheus-stack
./install.sh
cd -

echo "📊 Phase 4: Applying Monitoring Ingress..."
kubectl apply -f ../../k8s-manifests/monitoring/ingress/

# Phase 5: Testing
echo "🧪 Phase 5: Deploying Selenium Testing..."
kubectl apply -k ../../k8s-manifests/testing/selenium/

echo "✅ All deployments completed!"
EOF
chmod +x scripts/deployment/deploy-all.sh

# Validation script
cat > scripts/validation/validate-cluster.sh << 'EOF'
#!/bin/bash

echo "🔍 Validating Kubernetes Cluster..."

echo ""
echo "=== Node Status ==="
kubectl get nodes -o wide

echo ""
echo "=== Pod Status (All Namespaces) ==="
kubectl get pods -A | grep -v Running | grep -v Completed || echo "✅ All pods running"

echo ""
echo "=== Storage Status ==="
kubectl get storageclass
kubectl get pv
kubectl get pvc -A

echo ""
echo "=== Ingress Status ==="
kubectl -n ingress-nginx get svc
kubectl get ingress -A

echo ""
echo "=== Application Health ==="
echo "Flask API:"
kubectl -n flask-app get pods -o wide
echo ""
echo "Monitoring:"
kubectl -n monitoring get pods | grep -E 'prometheus|grafana|alertmanager'
echo ""
echo "Testing:"
kubectl -n testing get pods

echo ""
echo "✅ Validation complete"
EOF
chmod +x scripts/validation/validate-cluster.sh

# Backup script
cat > scripts/backup/backup-etcd.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/tmp/k8s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

echo "📦 Backing up etcd..."
kubectl -n kube-system exec -it etcd-cp-01 -- sh -c \
  "ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup-${TIMESTAMP}.db"

kubectl -n kube-system cp etcd-cp-01:/tmp/etcd-backup-${TIMESTAMP}.db \
  ${BACKUP_DIR}/etcd-backup-${TIMESTAMP}.db

echo "✅ Backup saved to: ${BACKUP_DIR}/etcd-backup-${TIMESTAMP}.db"
EOF
chmod +x scripts/backup/backup-etcd.sh

# Migration helper
cat > scripts/migration/export-grafana-dashboards.sh << 'EOF'
#!/bin/bash
# Export dashboards from old Grafana instance

OLD_GRAFANA="http://192.168.56.16:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
OUTPUT_DIR="./exported-dashboards"

mkdir -p $OUTPUT_DIR

echo "📊 Exporting Grafana dashboards..."

curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} ${OLD_GRAFANA}/api/search | \
  jq -r '.[] | select(.type == "dash-db") | .uid' | \
  while read uid; do
    echo "Exporting dashboard: $uid"
    curl -s -u ${GRAFANA_USER}:${GRAFANA_PASS} \
      "${OLD_GRAFANA}/api/dashboards/uid/${uid}" | \
      jq '.dashboard' > "${OUTPUT_DIR}/dashboard-${uid}.json"
  done

echo "✅ Dashboards exported to: $OUTPUT_DIR"
EOF
chmod +x scripts/migration/export-grafana-dashboards.sh

echo "  ✓ Scripts created"

# ============================================================================
# 6. DOCUMENTATION
# ============================================================================
echo "📁 Creating documentation directory..."

mkdir -p docs/{architecture,runbooks,troubleshooting}

cat > docs/README.md << 'EOF'
# Kubernetes Migration Documentation

## Directory Structure

- `architecture/` - Architecture diagrams and design decisions
- `runbooks/` - Operational procedures
- `troubleshooting/` - Common issues and solutions

## Quick Links

- [Migration Guide](../MIGRATION-GUIDE.md)
- [Day 2 Operations](./runbooks/day2-operations.md)
- [Troubleshooting Guide](./troubleshooting/common-issues.md)
EOF

touch docs/architecture/network-topology.md
touch docs/runbooks/{scaling.md,upgrades.md,backup-restore.md}
touch docs/troubleshooting/common-issues.md

echo "  ✓ Documentation structure created"

# ============================================================================
# 7. CONFIGURATION & ENVIRONMENT FILES
# ============================================================================
echo "📁 Creating configuration files..."

mkdir -p config/{production,staging,development}

cat > config/production/env.yaml << 'EOF'
# Production Environment Configuration
environment: production

flask:
  replicas: 3
  image_tag: main
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"

metallb:
  ip_range: "192.168.56.200-192.168.56.220"

ingress:
  domain: "internal"
  tls_enabled: false

monitoring:
  retention: 30d
  storage_size: 50Gi
EOF

echo "  ✓ Configuration files created"

# ============================================================================
# 8. ROOT LEVEL FILES
# ============================================================================
echo "📁 Creating root level files..."

cat > README.md << 'EOF'
# Kubernetes Migration Project

Migration from 6-VM setup to 8-node Kubernetes cluster with HA.

## Directory Structure

```
k8s-migration/
├── ansible/                    # Pre-migration infrastructure prep
│   ├── inventory/             # Ansible inventory files
│   ├── playbooks/             # Ansible playbooks
│   └── ansible.cfg            # Ansible configuration
├── kubespray-config/          # Kubespray configuration files
│   ├── inventory/             # Kubernetes cluster inventory
│   └── group_vars/            # Cluster variables
├── k8s-manifests/             # Kubernetes YAML manifests
│   ├── applications/          # Application deployments
│   ├── storage/               # Storage configurations
│   ├── networking/            # Network configurations
│   ├── monitoring/            # Monitoring stack
│   └── testing/               # Testing infrastructure
├── helm-values/               # Helm chart values
├── scripts/                   # Automation scripts
│   ├── deployment/            # Deployment automation
│   ├── validation/            # Validation scripts
│   ├── backup/                # Backup scripts
│   └── migration/             # Migration helpers
├── docs/                      # Documentation
├── config/                    # Environment configurations
└── README.md                  # This file
```

## Quick Start

### Phase 1: Prepare Infrastructure
```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/pre-migration-prep.yml
```

### Phase 2: Deploy Kubernetes
```bash
# Clone Kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout release-2.24

# Copy our configuration
cp -r ../kubespray-config/inventory/hosts.yaml inventory/mycluster/
cp -r ../kubespray-config/group_vars/k8s_cluster/* inventory/mycluster/group_vars/k8s_cluster/

# Deploy
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b
```

### Phase 3: Deploy Applications
```bash
cd scripts/deployment
./deploy-all.sh
```

### Phase 4: Validate
```bash
cd scripts/validation
./validate-cluster.sh
```

## Components

- **Control Plane**: 3 nodes (HA etcd + API server)
- **Workers**: 5 nodes (application workloads)
- **Storage**: Longhorn distributed block storage
- **Networking**: Calico CNI + MetalLB + Nginx Ingress
- **Monitoring**: Prometheus + Grafana + Alertmanager
- **Testing**: Selenium + Pushgateway

## Documentation

See [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) for detailed migration steps.

## Support

- Kubespray: https://kubespray.io/
- Longhorn: https://longhorn.io/docs/
- MetalLB: https://metallb.universe.tf/
EOF

cat > .gitignore << 'EOF'
# Kubernetes
*.kubeconfig
kubeconfig
admin.conf

# Ansible
*.retry
.ansible/
ansible/inventory/hosts.ini

# Secrets
*secret*.yaml
*secret*.yml
credentials*.yaml

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Logs
*.log

# Temporary files
tmp/
temp/
.DS_Store

# Backups
backups/
*.backup
*.bak

# IDE
.vscode/
.idea/
*.swp
*.swo

# Environment
.env
.env.*

# Kubespray (if cloned inside)
kubespray/
EOF

cat > Makefile << 'EOF'
.PHONY: help prepare deploy validate clean

help:
	@echo "Kubernetes Migration Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  prepare   - Prepare all nodes for Kubernetes"
	@echo "  deploy    - Deploy all Kubernetes components"
	@echo "  validate  - Validate cluster health"
	@echo "  clean     - Clean up resources"

prepare:
	@echo "🔧 Preparing infrastructure..."
	cd ansible && ansible-playbook -i inventory/hosts.ini playbooks/pre-migration-prep.yml

deploy:
	@echo "🚀 Deploying Kubernetes components..."
	cd scripts/deployment && ./deploy-all.sh

validate:
	@echo "🔍 Validating cluster..."
	cd scripts/validation && ./validate-cluster.sh

clean:
	@echo "🧹 Cleaning up..."
	kubectl delete namespace flask-app monitoring testing --ignore-not-found
EOF

echo "  ✓ Root files created"

# ============================================================================
# 9. CREATE PLACEHOLDER CONTENT FILES
# ============================================================================
echo "📝 Creating placeholder content..."

# Create placeholder notices in key files
cat > k8s-manifests/applications/flask-api/deployment.yaml << 'EOF'
# Place the Flask API deployment manifest here
# Copy content from artifact: flask-api-deployment.yaml
EOF

cat > k8s-manifests/storage/longhorn/values.yaml << 'EOF'
# Place the Longhorn Helm values here
# Copy content from artifact: longhorn-values.yaml
EOF

cat > k8s-manifests/networking/metallb/ipaddresspool.yaml << 'EOF'
# Place the MetalLB IP pool configuration here
# Copy content from artifact: metallb-config (IPAddressPool section)
EOF

cat > k8s-manifests/monitoring/prometheus-stack/values.yaml << 'EOF'
# Place the Prometheus stack Helm values here
# Copy content from artifact: prometheus-stack-values.yaml
EOF

echo "  ✓ Placeholder files created"

# ============================================================================
# 10. SUMMARY
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Project structure created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Project root: ${PROJECT_ROOT}/"
echo ""
echo "Next steps:"
echo "1. cd ${PROJECT_ROOT}"
echo "2. Copy artifact content into the respective files"
echo "3. Update inventory files with your actual IPs"
echo "4. Run: make prepare"
echo "5. Deploy Kubespray"
echo "6. Run: make deploy"
echo ""
echo "For detailed instructions, see: ${PROJECT_ROOT}/README.md"
echo "For migration guide, see: ${PROJECT_ROOT}/MIGRATION-GUIDE.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create tree view file
tree -L 3 -I 'kubespray' > project-structure.txt 2>/dev/null || echo "Install 'tree' for visual directory structure"

echo ""
echo "Run './setup-migration-project.sh' to create this structure!"
