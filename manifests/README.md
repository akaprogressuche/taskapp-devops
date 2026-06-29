Kubernetes Manifests

This directory contains all the Kubernetes YAML files for the TaskApp.
Argo CD watches this directory and keeps the cluster in sync with it.
You do not need to run kubectl apply manually - push to git and Argo CD handles it.

Directory layout:

  namespace.yml           the taskapp namespace
  configmap.yml           non-secret config values (DB host, port, env)
  backend/                Flask backend deployment and service
  frontend/               React frontend deployment and service
  postgres/               Postgres StatefulSet, service, and backup CronJob
  migrations/             one-off Job for database migrations
  ingress/                nginx Ingress and Let's Encrypt ClusterIssuer
  monitoring/             Prometheus values and ServiceMonitor
  advanced/               HPA, NetworkPolicy, PDB, LimitRange, ResourceQuota

Design decisions:

  Secrets are not in this directory. The taskapp-secrets Secret is created
  manually on the cluster with kubectl create secret. This keeps plaintext
  passwords out of git. See docs/RUNBOOK.md for the exact command.

  The monitoring/ subdirectory is excluded from the main Argo CD Application.
  It has its own Argo CD Application in gitops/apps/monitoring.yml that
  installs kube-prometheus-stack via Helm.

  The ingress/issuer.yml (Let's Encrypt ClusterIssuer) is also excluded
  from the Argo CD sync and applied once manually since it is cluster-scoped
  and only needs to exist once.

How Argo CD uses this:

  gitops/apps/taskapp.yml points Argo CD at this directory.
  Argo CD recursively scans all subdirectories.
  It excludes monitoring/ and ingress/issuer.yml.
  Automated sync with prune and selfHeal is enabled.
