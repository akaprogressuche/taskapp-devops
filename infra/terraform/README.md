Terraform - Infrastructure Provisioning

This directory creates all the AWS infrastructure for the cluster.

What it creates:

  - VPC with a public subnet and internet gateway
  - Security group for external traffic (SSH, HTTP, HTTPS only)
  - Security group for internal cluster traffic (all ports between nodes)
  - Three EC2 t3.small instances (1 control plane + 2 workers)
  - Three Elastic IPs so node addresses never change on reboot
  - SSH key pair from your public key file

Remote state is stored in S3 with locking so two people can not run
terraform apply at the same time and corrupt the state.

How to use:

  1. Copy the example vars file and fill it in:

       cp terraform.tfvars.example terraform.tfvars

  2. Edit terraform.tfvars with your values (SSH key path, region, etc.)

  3. Initialize and apply:

       terraform init
       terraform plan
       terraform apply

  4. Note the output IPs - you need them for the Ansible inventory.

Security notes:

  Port 22 is open to 0.0.0.0/0 because the student IP is dynamic.
  In a real production setup you would restrict this to your office CIDR.
  Port 6443 (k3s API) is only open within the VPC (10.0.0.0/16).
  The kubeconfig is git-ignored. Remote state is encrypted at rest.

Files:

  providers.tf            AWS provider, S3 backend config
  variables.tf            input variables with descriptions and defaults
  main.tf                 all resources (VPC, SGs, instances, EIPs)
  outputs.tf              node IPs printed after apply
  terraform.tfvars        your actual values (git-ignored)
  terraform.tfvars.example  template to copy from
