Ansible - Cluster Setup

This directory installs k3s on the three nodes and hardens them.

What it does:

  base-hardening role:
    - disables password SSH login (keys only)
    - configures UFW firewall (allows 22, 80, 443 from anywhere, cluster ports from VPC)
    - updates all packages
    - sets up fail2ban to block brute-force SSH attempts

  k3s-server role:
    - installs k3s server (the Kubernetes control plane) on the control plane node
    - saves the node join token to a file
    - fetches the kubeconfig back to the local machine
    - rewrites the kubeconfig server address from 127.0.0.1 to the public IP

  k3s-agent role:
    - installs k3s agent on each worker node
    - joins each worker to the cluster using the token from the server role

How to use:

  1. Copy and fill in the inventory:

       cp inventory/hosts.yml.example inventory/hosts.yml
       # then edit with the real node IPs from terraform output

  2. Run the full playbook:

       ansible-playbook -i inventory/hosts.yml site.yml

  3. The playbook is idempotent - running it a second time makes no changes.

  4. After it finishes, test from your machine:

       export KUBECONFIG=$(pwd)/../../kubeconfig
       kubectl get nodes

  You should see all three nodes with status Ready.

Files:

  site.yml                main playbook
  inventory/hosts.yml     real node IPs (git-ignored)
  group_vars/all.yml      shared variables
  roles/base-hardening/   firewall and SSH hardening
  roles/k3s-server/       control plane setup
  roles/k3s-agent/        worker node setup
