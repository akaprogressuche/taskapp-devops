GitOps with Argo CD

This directory contains Argo CD Application manifests. Each Application
tells Argo CD where to find the desired state for a part of the cluster.

How it works:

  Argo CD is installed on the cluster in the argocd namespace.
  It watches this git repository for changes.
  When you push a commit, Argo CD detects the drift and syncs within minutes.
  You never need to run kubectl apply for the app - git is the source of truth.

Applications:

  apps/taskapp.yml
    Watches the manifests/ directory in this repo.
    Deploys the full TaskApp stack (namespace, backend, frontend, postgres, etc.)
    Excludes monitoring/ (handled separately) and ingress/issuer.yml.
    Automated sync with prune (deletes removed resources) and selfHeal
    (reverts any manual kubectl changes).

  apps/monitoring.yml
    Installs kube-prometheus-stack via Helm from the Prometheus community chart repo.
    Uses manifests/monitoring/prometheus-values.yml from this repo as Helm values.
    This is a multi-source Application - one source is the Helm chart repo,
    the other is this git repo for the values file.

How to bootstrap Argo CD itself:

  Argo CD is not managed by Argo CD (the bootstrap problem).
  It was installed once with:

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  After that, apply the Application manifests from this directory:

    kubectl apply -f gitops/apps/

  From that point on, Argo CD manages itself and the cluster.

Argo CD UI:

  https://argocd.32.195.87.181.sslip.io
  Username: admin
  Password: retrieve with: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
