Project Decisions and Reasoning

This document explains what the project does, why each tool was chosen, and the thinking behind the key decisions. It is meant to help anyone reading this understand what was built and why.


What the Project Does

The project takes a web application called TaskApp and moves it from running on a single server into a production-style Kubernetes cluster running on AWS. TaskApp has three parts: a React frontend, a Flask backend, and a Postgres database.

The problem with running it on one server is simple. If that server goes down, the whole app goes down. The goal here is to fix that by spreading the app across multiple servers and automating how it is deployed and managed so it can survive failures and scale under load.


Why Terraform

Terraform is used to create the three EC2 instances on AWS. Without Terraform you would go into the AWS console and manually click around to create servers, security groups, networking, and so on. The problem with doing it manually is that there is no record of what settings were used and rebuilding from scratch means guessing.

With Terraform everything is written in files. If the cluster needs to be rebuilt, you just run terraform apply again and you get the exact same setup. This is called infrastructure as code.

Terraform tracks what it has already created in a state file. This project stores that state file in an S3 bucket so it is safe even if the laptop it was created from breaks. DynamoDB is used alongside S3 to handle locking, meaning if two people tried to run Terraform at the same time they cannot both write to the state file and corrupt it.


Why Three Servers

The cluster has one control plane node and two worker nodes.

The control plane is the brain of Kubernetes. It tracks what is supposed to be running, makes scheduling decisions, and handles API requests. It does not run the application itself.

The two worker nodes are where the application containers actually run. Having two workers means the app can survive one of them going down. If worker 1 fails, Kubernetes moves the pods that were running there over to worker 2 automatically. This is the failover scenario tested in the live demo.

All three use t3.small instances with 2 GB of RAM each. The AWS Free Tier t2.micro (1 GB) is too small to run k3s together with all the platform tools like Argo CD, cert-manager, and Prometheus without running out of memory.


Why Ansible

After Terraform creates the servers they are just blank Ubuntu machines. Ansible is used to configure them. It connects over SSH and runs tasks on each server in a specific order.

Ansible does three things in this project:

1. Base hardening on every node. It creates a non-root user, disables password authentication on SSH so only key-based login works, and sets up a UFW firewall that only allows the ports the cluster actually needs.

2. Install k3s on the control plane. k3s is a lightweight version of Kubernetes that installs with a single curl command. After it is installed, Ansible reads the join token k3s generates and downloads the kubeconfig to the local machine so kubectl can connect to the cluster.

3. Join the worker nodes. Ansible takes that join token and runs the k3s agent install command on each worker, passing it the control plane address and token. The workers register with the control plane and show up in kubectl get nodes.

The reason Ansible is better than running shell scripts manually is that the playbooks are idempotent. That means you can run the same playbook multiple times and it will not break anything or create duplicates. If a step is already done, Ansible detects that and skips it.


Why k3s Instead of Full Kubernetes

Full Kubernetes installed with kubeadm requires manually setting up many separate components like etcd, the API server, the controller manager, and the scheduler. k3s packages all of that into one binary and handles most of the setup automatically. It is still real Kubernetes. All the same kubectl commands and all the same YAML manifests work exactly the same way. For a project where you are managing the cluster yourself on a small budget, k3s is the practical choice.


The Kubernetes Manifests

Namespace: separates the TaskApp from anything else that might run on the cluster. All resources for this project live inside the taskapp namespace.

ConfigMap: holds configuration values that are not sensitive, like the database hostname, port number, and environment name. These are passed into containers as environment variables.

Secrets: hold the database password and the Flask secret key. The actual password values are never written into any file in this repository. The secret is created with a kubectl command run directly against the cluster. If a password was ever committed to git, it would be a security violation and extremely hard to remove from the history.

Postgres StatefulSet: deploys the database. A StatefulSet is used instead of a regular Deployment because the database needs persistent storage and a stable network identity. A PersistentVolumeClaim is attached to it which reserves disk storage. If the Postgres pod restarts, it reconnects to the same disk and the data is still there.

Migration Job: runs database migrations as a one-off Kubernetes Job before the backend starts. The reason for doing it as a Job rather than inside the container startup script is that with two backend replicas both would try to run migrations at the same time on startup. That causes race conditions and can corrupt the schema. A Job runs once, finishes, and then the backend pods start cleanly.

Backend and Frontend Deployments: both have two replicas that are spread across the two worker nodes using topology spread constraints. One replica runs on worker-1 and one on worker-2. If a worker goes down the other still has a running replica. Both use maxUnavailable set to 0 in their rolling update strategy, meaning new pods come up and become healthy before old ones are removed. The app is never completely down during a deploy.

Health probes: every container has a liveness probe and a readiness probe. The liveness probe checks if the container is still running correctly. If it fails, Kubernetes restarts the container. The readiness probe checks if the container is ready to receive traffic. If it fails, Kubernetes stops sending requests to that pod without restarting it. The startup probe gives extra time for slow-starting containers before the liveness probe takes over.

Ingress: the single entry point for all internet traffic. The nginx ingress controller receives requests, terminates TLS, and routes them. Requests to /api go to the backend service. Everything else goes to the frontend service. TLS is handled at the ingress so internal services use plain HTTP.

cert-manager: installed on the cluster to manage TLS certificates automatically. The ClusterIssuer resource points to Let's Encrypt. When an Ingress with the cert-manager annotation is created, cert-manager requests a certificate, proves domain ownership through an HTTP01 challenge, and Let's Encrypt issues a real signed certificate. cert-manager stores it as a Kubernetes secret and renews it before it expires.

sslip.io: used as the domain. It is a free DNS service where the domain name itself contains the IP address. For example taskapp.54.12.34.56.sslip.io automatically resolves to 54.12.34.56. This gives a real domain that Let's Encrypt will issue certificates for without needing to buy anything.


All Five Advanced Features

Horizontal Pod Autoscaler: watches the CPU usage of backend pods. When average CPU goes above 70 percent it adds more pods, up to 5. When the load drops it scales back down to 2. This is demonstrated by running a load test and watching kubectl get hpa show the replica count increase.

NetworkPolicy: controls which pods can talk to which other pods. By default in Kubernetes every pod can reach every other pod across the cluster. The NetworkPolicy here sets a default-deny rule on the taskapp namespace and then adds specific allow rules. Only the backend can reach Postgres on port 5432. Only the ingress controller can reach the frontend and backend. This limits what an attacker can access if they compromise one part of the app.

PodDisruptionBudget: protects the app during planned maintenance like draining a node. When a node is drained, Kubernetes tries to evict all its pods. The PDB says at least one backend replica and one frontend replica must stay running at all times. Kubernetes will not evict a pod if doing so would break that rule.

Observability stack: Prometheus is installed to scrape metrics from the cluster and the application. Grafana is installed to display those metrics as dashboards. The ServiceMonitor resource tells Prometheus to scrape the backend pods specifically. During the demo you can open Grafana and show CPU and memory per pod, request rates, and the CPU spike during the load test.

Security hardening: containers run as non-root users. Backend runs as user 1000, frontend as user 101. Both have readOnlyRootFilesystem set to true so nothing can be written to the container filesystem at runtime. The frontend needs writable directories for nginx cache and pid files so those are mounted as emptyDir volumes. A LimitRange sets default resource limits for any container that does not specify its own, preventing a runaway process from consuming all node memory. A ResourceQuota caps total CPU and memory the whole taskapp namespace can use.


Why Argo CD for GitOps

GitOps means the desired state of the cluster lives in git. Argo CD is installed on the cluster and watches the manifests/ folder in this repository. Every few minutes it compares what is in git to what is running on the cluster. If there is a difference it applies the change automatically.

To deploy a change you update a manifest file, commit, and push. Argo CD picks it up and applies it. No manual kubectl apply commands are needed. If someone makes a manual change on the cluster directly, Argo CD reverts it back to what git says on the next sync. This is the self-healing behaviour.


Security Summary

The Kubernetes API port 6443 is not open to the internet, only within the VPC. SSH access is restricted to one operator IP in the AWS security group. Container images are pinned to specific version tags so you always know exactly what is running. Secrets are never in git. Containers do not run as root. NetworkPolicy enforces least-privilege communication between pods.
