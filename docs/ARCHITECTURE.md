Architecture Overview

TaskApp is a three-tier web application deployed on a self-managed Kubernetes cluster running on AWS. It has a React frontend, a Flask backend, and a PostgreSQL database. The cluster is provisioned with Terraform, configured with Ansible, and managed through GitOps using Argo CD.


Cluster Topology

The cluster has three EC2 instances all running in the us-east-1a availability zone inside the same VPC (10.0.0.0/16).

- control-plane node (t3.small): runs k3s server, Argo CD, nginx ingress controller, cert-manager, Prometheus, and Grafana. It has an Elastic IP so the public address never changes.
- worker-1 node (t3.small): runs one replica of the backend and one replica of the frontend.
- worker-2 node (t3.small): runs the second replica of the backend and the second replica of the frontend.

The three nodes talk to each other freely over the internal security group. The Kubernetes API port 6443 is only open within the VPC. It is not exposed to the internet.


How a Request Gets to the App

1. A user opens https://taskapp.<ip>.sslip.io in their browser.
2. sslip.io DNS resolves the domain to the control plane Elastic IP.
3. The nginx ingress controller on the control plane receives the request.
4. nginx terminates TLS using the Let's Encrypt certificate that cert-manager manages.
5. Requests to /api are forwarded to the backend ClusterIP service on port 80.
6. All other requests go to the frontend ClusterIP service on port 80.
7. The frontend serves the React static files to the browser.
8. The React app makes API calls to /api which go through the same ingress to the backend.
9. The backend connects to Postgres using the hostname postgres-service, which Kubernetes DNS resolves to the Postgres ClusterIP service inside the taskapp namespace.


How This Fixes the Single-Server Problem

The original Docker setup ran everything on one machine. The problems with that are:

1. If the server goes down, the whole app goes down with it.
2. Scaling requires upgrading that one machine which takes downtime.
3. There is no way to do zero-downtime deployments on a single machine running one container per service.

This project fixes all three problems:

1. Two worker nodes mean the app survives one node failing. Pod replicas are spread across different nodes, so if worker-1 goes down, worker-2 still has one running replica of each service.
2. The HPA adds more backend pods when CPU is high without touching the servers at all.
3. Rolling updates with maxUnavailable set to 0 mean new pods come up and become healthy before old ones are removed, so the app never has zero pods serving traffic.


GitOps Flow

The way deployments work in this project is through git, not through kubectl commands.

1. A change is pushed to the main branch on GitHub.
2. Argo CD polls the repository every few minutes and detects that the cluster state no longer matches what is in git.
3. Argo CD applies the updated manifests to the cluster.
4. Kubernetes performs a rolling update with no downtime.

No manual kubectl apply commands are used for deploying the application. Git is the single source of truth.


Namespace Isolation

Application resources live in the taskapp namespace. The monitoring stack lives in monitoring. Argo CD lives in argocd. This separation means a problem in one namespace does not directly affect the others.


Certificate Management

cert-manager is installed on the cluster. The ClusterIssuer resource points to the Let's Encrypt production ACME server. When the Ingress resource is created with the cert-manager annotation, cert-manager requests a certificate automatically. It proves domain ownership by temporarily serving a file at /.well-known/acme-challenge/ and Let's Encrypt fetches it. Once verified, Let's Encrypt issues a real signed certificate which cert-manager stores as a Kubernetes secret. The certificate renews automatically before it expires.

sslip.io is used as the domain. It is a free service where the domain name contains the IP address. For example if the control plane IP is 54.12.34.56, the domain taskapp.54.12.34.56.sslip.io automatically resolves to that IP. This means no domain purchase is needed while still getting a real domain that Let's Encrypt will issue certificates for.


Security Decisions

- SSH is restricted to one operator IP via the AWS security group. No other IP can connect.
- The Kubernetes API (port 6443) is not open to the internet, only within the VPC.
- Backend containers run as user 1000 and frontend containers run as user 101. Neither runs as root.
- Container root filesystems are set to read-only. The two writable paths nginx needs (cache and pid file) are mounted as emptyDir volumes instead.
- NetworkPolicy sets a default-deny rule in the taskapp namespace. Only the backend can reach Postgres on port 5432. Only the ingress controller can reach the frontend and backend.
- Secrets are never written to git. They are created directly on the cluster with kubectl.
- All container images are pinned to a specific commit SHA like 5d6b8fc. The latest tag is never used because it can change without warning.
