# k0s High-Availability Cluster Deployment

This repository contains Ansible playbooks and configurations for deploying a highly available k0s Kubernetes cluster with enterprise-grade components.

## Architecture

- **3 Ubuntu hosts** with mixed controller/worker roles
- **2 k0s controllers** for high availability
- **3 worker nodes** for workload distribution
- **Tolerance for one host failure** through proper distribution
- **Longhorn storage** with distributed replication
- **Rancher** for cluster administration
- **MetalLB** for load balancing
- **PostgreSQL** with high availability using CloudNativePG
- **Optional KubeVirt** integration for virtual machine workloads

## Prerequisites

- Ubuntu 22.04 LTS hosts with minimum specifications:
  - CPU: 4 cores
  - Memory: 8GB RAM
  - System Storage: 50GB SSD
  - Dedicated Storage Drive: 200GB+ SSD
  - Dual Network Interfaces (eth0: public, eth1: private)
- Ansible 2.12+ on control node
- SSH access with sudo privileges on all hosts

## Configuration

### 1. Update Inventory

Edit `inventory/hosts.ini` with your host information:

```ini
[controllers]
k0s-1 ansible_host=YOUR_PUBLIC_IP1 ansible_user=ubuntu private_ip=10.0.0.10 storage_device=/dev/sdb
k0s-2 ansible_host=YOUR_PUBLIC_IP2 ansible_user=ubuntu private_ip=10.0.0.11 storage_device=/dev/sdb

[workers]
k0s-1 ansible_host=YOUR_PUBLIC_IP1 ansible_user=ubuntu private_ip=10.0.0.10 storage_device=/dev/sdb
k0s-2 ansible_host=YOUR_PUBLIC_IP2 ansible_user=ubuntu private_ip=10.0.0.11 storage_device=/dev/sdb
k0s-3 ansible_host=YOUR_PUBLIC_IP3 ansible_user=ubuntu private_ip=10.0.0.12 storage_device=/dev/sdb
```

### 2. Update Variables

Edit `group_vars/all.yml` with your configuration:

```yaml
# Load balancer
load_balancer_ip: "YOUR_PUBLIC_IP"

# Rancher
rancher_admin_password: "your_secure_password"

# AWS/Backup credentials
aws_access_key: "YOUR_AWS_ACCESS_KEY"
aws_secret_key: "YOUR_AWS_SECRET_KEY"
postgres_password: "YOUR_POSTGRES_PASSWORD"
```

## Deployment

### Option 1: Complete Deployment

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

### Option 2: Step-by-Step Deployment

```bash
# Setup controllers first
ansible-playbook -i inventory/hosts.ini playbooks/setup-controllers.yml

# Then setup workers
ansible-playbook -i inventory/hosts.ini playbooks/setup-workers.yml

# Deploy storage and load balancer
ansible-playbook -i inventory/hosts.ini playbooks/deploy-storage.yml

# Deploy Rancher
ansible-playbook -i inventory/hosts.ini playbooks/deploy-rancher.yml

# Deploy applications (PostgreSQL)
ansible-playbook -i inventory/hosts.ini playbooks/deploy-apps.yml
```

## Access

After deployment:

- **Rancher**: https://rancher.YOUR_PUBLIC_IP.nip.io
  - Username: admin
  - Password: (as configured in group_vars/all.yml)

- **PostgreSQL**: YOUR_PUBLIC_IP:5432
  - Database: appdb
  - Username: appuser
  - Password: (as configured in group_vars/all.yml)

## Optional: KubeVirt Deployment

To deploy KubeVirt for virtual machine workloads:

```bash
ansible-playbook -i inventory/hosts.ini -e "target_hosts=controllers[0]" roles/kubevirt/tasks/main.yml
```

Example VM manifest is available in `files/example-vm.yaml`.

## Cluster Management

### Verify Cluster Status

```bash
ansible -i inventory/hosts.ini controllers -m shell -a "k0s kubectl get nodes"
```

### Upgrade Cluster

```bash
ansible-playbook -i inventory/hosts.ini playbooks/upgrade-cluster.yml -e "k0s_new_version=v1.27.4+k0s.0"
```

### Backup and Recovery

```bash
# Create etcd backup
ansible -i inventory/hosts.ini controllers -m shell -a "sudo k0s etcd snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db"

# Restore from backup
ansible -i inventory/hosts.ini controllers -m shell -a "sudo k0s stop controller && sudo k0s etcd snapshot restore /backup/etcd-backup.db && sudo k0s start controller"
```

## Troubleshooting

### Common Issues

1. **Controller Won't Start**
   ```bash
   ansible -i inventory/hosts.ini controllers -m shell -a "sudo k0s status"
   ansible -i inventory/hosts.ini controllers -m shell -a "sudo journalctl -u k0scontroller -f"
   ```

2. **Worker Can't Join Cluster**
   ```bash
   ansible -i inventory/hosts.ini workers -m shell -a "cat /tmp/worker-token"
   ansible -i inventory/hosts.ini workers -m shell -a "telnet <controller-ip> 6443"
   ```

3. **Longhorn Issues**
   ```bash
   ansible -i inventory/hosts.ini controllers -m shell -a "sudo k0s kubectl get pods -n longhorn-system"
   ansible -i inventory/hosts.ini controllers -m shell -a "sudo k0s kubectl get storageclass"
   ```

## Security Considerations

- Ensure only necessary ports are open between cluster nodes
- Implement proper RBAC policies
- Enable etcd encryption for sensitive data
- Regularly update k0s and components
- Implement backup and disaster recovery procedures

## Support

For additional information:
- [k0s Documentation](https://docs.k0sproject.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Rancher Documentation](https://rancher.com/docs/)
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)