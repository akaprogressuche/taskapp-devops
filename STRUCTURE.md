Repository Structure

taskapp-devops/
  README.md                       this file's sibling - project overview
  STRUCTURE.md                    this file
  .gitignore                      keeps secrets, state files, and kubeconfig out of git

  infra/
    terraform/
      providers.tf                AWS provider config and S3 remote state backend
      variables.tf                all input variables (region, instance types, etc.)
      main.tf                     VPC, subnets, security groups, EC2 instances, EIPs
      outputs.tf                  node public/private IPs for Ansible to consume
      terraform.tfvars.example    example values file - copy to terraform.tfvars and fill in
      modules/                    reusable modules if any

    ansible/
      site.yml                    main playbook - runs all roles in order
      inventory/
        hosts.yml                 node IPs (git-ignored, contains real IPs)
      group_vars/
        all.yml                   variables shared across all nodes
      roles/
        base-hardening/           SSH keys only, UFW firewall, non-root user, fail2ban
        k3s-server/               installs k3s server, saves node token, fetches kubeconfig
        k3s-agent/                joins worker nodes to the cluster using the token

  manifests/
    namespace.yml                 taskapp namespace
    configmap.yml                 non-secret config (DB host, port, name, Flask env)
    ingress/
      ingress.yml                 nginx Ingress with TLS for frontend and backend
      issuer.yml                  Let's Encrypt ClusterIssuer for cert-manager
    backend/
      deployment.yml              Flask backend, 2 replicas, probes, security context
      service.yml                 ClusterIP service for the backend
    frontend/
      deployment.yml              React/nginx frontend, 2 replicas, probes, security context
      service.yml                 ClusterIP service for the frontend
    postgres/
      statefulset.yml             Postgres StatefulSet with PVC for persistent storage
      service.yml                 ClusterIP service for Postgres
      backup-cronjob.yml          daily pg_dump to S3 (runs at 2am UTC)
    migrations/
      job.yml                     one-off Job that runs alembic upgrade head before the app starts
    monitoring/
      namespace.yml               monitoring namespace
      prometheus-values.yml       Helm values for kube-prometheus-stack
      servicemonitor.yml          tells Prometheus to scrape the backend
    advanced/
      hpa.yml                     HPA - scales backend between 2 and 5 replicas on CPU
      networkpolicy.yml           default-deny + specific allow rules per service
      pdb.yml                     PodDisruptionBudget so drains don't kill the app
      security.yml                LimitRange and ResourceQuota for the namespace

  gitops/
    apps/
      taskapp.yml                 Argo CD Application for the main app manifests
      monitoring.yml              Argo CD Application for the kube-prometheus-stack Helm chart

  docs/
    ARCHITECTURE.md               node topology, networking, request flow diagram
    RUNBOOK.md                    exact commands to provision, deploy, scale, recover
    COST.md                       itemized monthly cost and how to cut it
    DECISIONS.md                  why each tool and approach was chosen
    EVIDENCE/
      README.md                   checklist of 30 screenshots to capture for submission
      (screenshots go here)
