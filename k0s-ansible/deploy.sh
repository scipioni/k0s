#!/bin/bash

# k0s Cluster Deployment Script
# This script automates the deployment of a highly available k0s Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate configuration
validate_config() {
    print_status "Validating configuration..."
    
    # Check if inventory file exists
    if [ ! -f "inventory/hosts.ini" ]; then
        print_error "inventory/hosts.ini not found. Please configure your hosts first."
        exit 1
    fi
    
    # Check if variables are configured
    # if grep -q "YOUR_PUBLIC_IP" group_vars/all.yml; then
    #     print_error "Please update group_vars/all.yml with your actual configuration values."
    #     exit 1
    # fi
    
    # Check if inventory has actual host IPs
    if grep -q "10.1.109.20" inventory/hosts.ini; then
        print_warning "Please update inventory/hosts.ini with your actual host IPs."
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "Configuration validation completed"
}

# Function to install Ansible collections
install_requirements() {
    print_status "Installing Ansible collections and requirements..."
    
    if command_exists ansible-galaxy; then
        ansible-galaxy install -r requirements.yml
        print_success "Ansible collections installed"
    else
        print_error "ansible-galaxy not found. Please install Ansible first."
        exit 1
    fi
}

# Function to test connectivity
test_connectivity() {
    print_status "Testing connectivity to hosts..."
    
    if ansible all -i inventory/hosts.ini -m ping >/dev/null 2>&1; then
        print_success "Connectivity test passed"
    else
        print_error "Connectivity test failed. Please check your SSH configuration and host accessibility."
        exit 1
    fi
}

# Function to deploy complete cluster
deploy_complete() {
    print_status "Starting complete k0s cluster deployment..."
    
    print_status "Step 1: Setting up cluster prerequisites and controllers..."
    ansible-playbook -i inventory/hosts.ini playbooks/setup-controllers.yml
    
    print_status "Step 2: Setting up worker nodes..."
    ansible-playbook -i inventory/hosts.ini playbooks/setup-workers.yml
    
    print_status "Step 3: Deploying storage and load balancer..."
    ansible-playbook -i inventory/hosts.ini playbooks/deploy-storage.yml
    
    print_status "Step 4: Deploying Rancher management platform..."
    ansible-playbook -i inventory/hosts.ini playbooks/deploy-rancher.yml
    
    print_status "Step 5: Deploying applications (PostgreSQL)..."
    ansible-playbook -i inventory/hosts.ini playbooks/deploy-apps.yml
    
    print_success "Complete cluster deployment finished!"
}

# Function to deploy step by step
deploy_step_by_step() {
    print_status "Starting step-by-step deployment..."
    
    echo "Choose deployment step:"
    echo "1) Setup controllers"
    echo "2) Setup workers"
    echo "3) Deploy storage and load balancer"
    echo "4) Deploy Rancher"
    echo "5) Deploy applications"
    echo "6) Exit"
    
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            print_status "Setting up controllers..."
            ansible-playbook -i inventory/hosts.ini playbooks/setup-controllers.yml
            ;;
        2)
            print_status "Setting up workers..."
            ansible-playbook -i inventory/hosts.ini playbooks/setup-workers.yml
            ;;
        3)
            print_status "Deploying storage and load balancer..."
            ansible-playbook -i inventory/hosts.ini playbooks/deploy-storage.yml
            ;;
        4)
            print_status "Deploying Rancher..."
            ansible-playbook -i inventory/hosts.ini playbooks/deploy-rancher.yml
            ;;
        5)
            print_status "Deploying applications..."
            ansible-playbook -i inventory/hosts.ini playbooks/deploy-apps.yml
            ;;
        6)
            print_status "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Function to upgrade cluster
upgrade_cluster() {
    print_status "Upgrading k0s cluster..."
    
    read -p "Enter the target k0s version (default: v1.27.4+k0s.0): " version
    version=${version:-"v1.27.4+k0s.0"}
    
    print_status "Upgrading to version: $version"
    ansible-playbook -i inventory/hosts.ini playbooks/upgrade-cluster.yml -e "k0s_new_version=$version"
    
    print_success "Cluster upgrade completed"
}

# Function to show cluster status
show_status() {
    print_status "Checking cluster status..."
    
    echo "=== Node Status ==="
    ansible controllers -i inventory/hosts.ini -m shell -a "k0s kubectl get nodes" || print_warning "Could not get node status"
    
    echo ""
    echo "=== Pod Status ==="
    ansible controllers -i inventory/hosts.ini -m shell -a "k0s kubectl get pods --all-namespaces" || print_warning "Could not get pod status"
    
    echo ""
    echo "=== Service Status ==="
    ansible controllers -i inventory/hosts.ini -m shell -a "k0s kubectl get services --all-namespaces" || print_warning "Could not get service status"
}

# Function to cleanup deployment
cleanup() {
    print_warning "This will remove k0s from all hosts. Are you sure?"
    read -p "Type 'DELETE' to confirm: " confirm
    
    if [ "$confirm" = "DELETE" ]; then
        print_status "Cleaning up k0s deployment..."
        ansible cluster -i inventory/hosts.ini -m shell -a "sudo k0s reset && sudo rm -rf /var/lib/k0s" || print_warning "Cleanup may not be complete"
        print_success "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show access information
show_access_info() {
    print_status "Retrieving access information..."
    
    # Get load balancer IP from variables
    LB_IP=$(grep "load_balancer_ip:" group_vars/all.yml | awk '{print $2}')
    
    echo ""
    print_success "=== Access Information ==="
    echo "Rancher URL: https://rancher.${LB_IP}.nip.io"
    echo "PostgreSQL: ${LB_IP}:5432"
    echo ""
    echo "Default Credentials:"
    echo "- Rancher Username: admin"
    echo "- Rancher Password: Check group_vars/all.yml"
    echo "- PostgreSQL Database: appdb"
    echo "- PostgreSQL Username: appuser"
    echo "- PostgreSQL Password: Check group_vars/all.yml"
    echo ""
    echo "To get Rancher password:"
    echo "ansible controllers -i inventory/hosts.ini -m shell -a \"sudo k0s kubectl get secret --namespace cattle-system rancher-admin-password -o go-template='{{.data.password}}{{\"\\n\"}}' | base64 -d\""
}

# Main menu
show_menu() {
    echo ""
    print_success "=== k0s Cluster Deployment Script ==="
    echo "1) Complete Deployment"
    echo "2) Step-by-Step Deployment"
    echo "3) Upgrade Cluster"
    echo "4) Show Cluster Status"
    echo "5) Show Access Information"
    echo "6) Test Connectivity"
    echo "7) Cleanup Deployment"
    echo "8) Exit"
    echo ""
}

# Main execution
main() {
    print_status "k0s Cluster Deployment Script"
    
    # Check if we're in the right directory
    if [ ! -f "ansible.cfg" ]; then
        print_error "Please run this script from the k0s-ansible directory"
        exit 1
    fi
    
    # Validate configuration first
    validate_config
    
    # Install requirements
    install_requirements
    
    while true; do
        show_menu
        read -p "Enter your choice (1-8): " choice
        
        case $choice in
            1)
                deploy_complete
                ;;
            2)
                deploy_step_by_step
                ;;
            3)
                upgrade_cluster
                ;;
            4)
                show_status
                ;;
            5)
                show_access_info
                ;;
            6)
                test_connectivity
                ;;
            7)
                cleanup
                ;;
            8)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1-8."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"