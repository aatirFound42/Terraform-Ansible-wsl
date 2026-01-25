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
