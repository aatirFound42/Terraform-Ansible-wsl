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
