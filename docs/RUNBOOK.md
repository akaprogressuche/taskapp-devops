Runbook

This document covers every step needed to go from nothing to a running cluster. Anyone should be able to follow this from scratch.


Tools Needed

Install these before starting:

```
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
pip3 install ansible
brew install awscli
aws configure
brew install kubectl
brew install hey
```

Also make sure you have an SSH key:

```
ls ~/.ssh/id_rsa.pub || ssh-keygen -t rsa -b 4096
```


Step 1 - Create the Terraform state bucket

This only runs once. It creates the S3 bucket and DynamoDB table Terraform uses to save its state.

```
cd infra/terraform
bash bootstrap-state.sh
```


Step 2 - Provision the three servers

```
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Find your current IP address:

```
curl ifconfig.me
```

Open terraform.tfvars and set allowed_ssh_cidr to your IP followed by /32, for example 41.190.12.5/32.

Then run:

```
terraform init
terraform plan
terraform apply
```

When it finishes, run this to see the server IPs:

```
terraform output
```

You will see control_plane_ip, worker_ips, and app_domain_hint. Write these down.


Step 3 - Set up the Ansible inventory

```
cd infra/ansible
cp inventory/hosts.yml.example inventory/hosts.yml
```

Open inventory/hosts.yml and replace the placeholder IPs with the real IPs from the terraform output.


Step 4 - Run the Ansible playbook

Test that Ansible can reach the servers first:

```
ansible all -i inventory/hosts.yml -m ping
```

Then run the full setup:

```
ansible-playbook -i inventory/hosts.yml site.yml
```

This takes about 5 minutes. You should see no failed tasks at the end.


Step 5 - Check the cluster is up

The playbook saves a kubeconfig file to the project root. Point kubectl at it:

```
export KUBECONFIG="$(pwd)/kubeconfig"
kubectl get nodes
```

You should see three nodes all showing Ready. If any node shows NotReady wait a minute and check again.


Step 6 - Install platform tools on the cluster

```
cd infra/ansible
ansible-playbook -i inventory/hosts.yml roles/k3s-server/tasks/platform.yml
```

This installs the nginx ingress controller, cert-manager, Argo CD, and metrics-server. Wait for cert-manager to finish starting:

```
kubectl rollout status deployment/cert-manager -n cert-manager
```


Step 7 - Apply the certificate issuer

```
kubectl apply -f manifests/ingress/issuer.yml
```


Step 8 - Set the real domain in the ingress files

Open manifests/ingress/ingress.yml and replace CONTROL_PLANE_IP with the actual IP from terraform output. Do the same in manifests/monitoring/prometheus-values.yml for the Grafana ingress.

Commit and push:

```
git add manifests/ingress/ingress.yml manifests/monitoring/prometheus-values.yml
git commit -m "Set real IP in ingress"
git push
```


Step 9 - Create the application secrets

Secrets are never stored in git. Create them directly on the cluster:

```
kubectl create secret generic taskapp-secrets \
  --namespace taskapp \
  --from-literal=DATABASE_USER=taskapp \
  --from-literal=DATABASE_PASSWORD='choose-a-strong-password' \
  --from-literal=SECRET_KEY='choose-a-flask-secret-key'
```


Step 10 - Connect Argo CD

Get the Argo CD admin password:

```
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

Apply the Argo CD application files:

```
kubectl apply -f gitops/apps/taskapp.yml
kubectl apply -f gitops/apps/monitoring.yml
```

Watch until both show Synced and Healthy:

```
kubectl get applications -n argocd -w
```


Step 11 - Run database migrations

```
kubectl apply -f manifests/migrations/job.yml
kubectl wait --for=condition=complete job/db-migrate -n taskapp --timeout=120s
kubectl logs job/db-migrate -n taskapp
```


Step 12 - Verify the app is working

```
kubectl get pods -n taskapp -o wide
kubectl get ingress -n taskapp
curl -I https://taskapp.YOUR_IP.sslip.io
```

The TLS certificate can take 2 to 3 minutes to issue after the ingress is created. If you get a certificate error, wait and try again.


Deploying a new version

1. Edit manifests/backend/deployment.yml and change the image tag.
2. Commit and push to git.
3. Argo CD picks up the change within 3 minutes and rolls it out.
4. Watch the rollout: kubectl rollout status deployment/taskapp-backend -n taskapp

No downtime happens because maxUnavailable is set to 0.


Scaling manually

```
kubectl scale deployment taskapp-backend --replicas=3 -n taskapp
```

Note that Argo CD will revert this back to 2 replicas on the next sync because it enforces what git says. To make a permanent change, update the manifest and push.


Rolling back

```
kubectl rollout undo deployment/taskapp-backend -n taskapp
kubectl rollout status deployment/taskapp-backend -n taskapp
```

For a permanent rollback, change the image tag in git and push.


Failover demo

Find the worker node names:

```
kubectl get nodes
```

Run the failover script:

```
bash scripts/failover-demo.sh <worker-node-name> taskapp.YOUR_IP.sslip.io
```

The script drains the node, checks the app is still responding, then brings the node back online.


Load test for HPA demo

Open two terminals.

Terminal 1 - watch the HPA:

```
kubectl get hpa -n taskapp -w
```

Terminal 2 - run the load test:

```
bash scripts/load-test.sh taskapp.YOUR_IP.sslip.io
```

After a minute or two the HPA will increase the backend replica count. When the load test ends and CPU drops, it scales back down to 2.


Grafana dashboards

Grafana is at https://grafana.YOUR_IP.sslip.io. Username is admin. The password was set during the monitoring install.

Dashboards to show during the viva:
- Kubernetes / Compute Resources / Namespace (Pods) - shows CPU and memory per pod
- Kubernetes / Networking / Namespace (Pods) - shows request rates
- Node Exporter / Nodes - shows per-node CPU, memory, and disk


Teardown after grading

Run this to remove all AWS resources and stop all billing:

```
cd infra/terraform
terraform destroy
```

The S3 bucket and DynamoDB table cost almost nothing and can stay.
