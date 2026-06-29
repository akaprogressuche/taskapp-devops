Evidence Folder

This folder contains screenshots and terminal output captured during the deployment and demo. Each file is named to match the requirement it proves.

Checklist of what to capture:


Infrastructure

01-nodes-ready.png
    kubectl get nodes showing all 3 nodes with Ready status

02-pod-distribution.png
    kubectl get pods -n taskapp -o wide showing pods running on different worker nodes

03-terraform-output.png
    terminal showing terraform output with the three IPs


TLS and Ingress

04-https-browser.png
    browser showing the app loaded over HTTPS with a padlock icon

05-cert-details.png
    browser certificate popup showing Let's Encrypt as the certificate authority

06-cert-ready.png
    kubectl get certificate -n taskapp showing READY as True


Data Persistence

07-pvc-bound.png
    kubectl get pvc -n taskapp showing the Postgres volume with Bound status

08-tasks-before-restart.png
    tasks visible in the app before the Postgres pod is restarted

09-postgres-pod-restart.png
    kubectl delete pod postgres-0 -n taskapp and the pod coming back

10-tasks-after-restart.png
    same tasks still visible in the app after Postgres restarted


Zero-Downtime Deployment

11-rolling-update.png
    kubectl rollout status deployment/taskapp-backend -n taskapp showing the rollout completing

12-no-downtime-curl.png
    continuous curl output during a deploy showing no failed requests


GitOps

13-argocd-synced.png
    Argo CD UI showing the taskapp application as Synced and Healthy

14-commit-to-cluster.png
    sequence showing a git push followed by Argo CD detecting the change and a new pod running


Horizontal Pod Autoscaling

15-hpa-at-rest.png
    kubectl get hpa -n taskapp showing 2 replicas before the load test

16-hpa-scaling-up.png
    HPA showing a higher replica count during the load test

17-hpa-scaling-down.png
    HPA scaling back down to 2 replicas after the load test ends

18-grafana-cpu-spike.png
    Grafana dashboard showing the CPU usage spike during the load test


NetworkPolicy

19-networkpolicies.png
    kubectl get networkpolicy -n taskapp listing all the network policies

20-db-access-blocked.png
    a pod outside the backend trying to connect to Postgres on port 5432 and being refused


PodDisruptionBudget

21-pdb-list.png
    kubectl get pdb -n taskapp showing backend-pdb and frontend-pdb


Failover Demo

22-before-drain.png
    kubectl get pods -n taskapp -o wide showing pods spread across both workers before the drain

23-drain-running.png
    kubectl drain command output showing pods being evicted from the node

24-app-responding-during-drain.png
    curl output showing the app still returns 200 while the node is drained

25-uncordon-recovery.png
    kubectl get nodes showing the node back to Ready and pods rescheduling across both workers


Observability

26-prometheus-targets.png
    Prometheus targets page showing the backend pods being scraped successfully

27-grafana-pod-resources.png
    Grafana Kubernetes / Compute Resources / Namespace dashboard showing CPU and memory per pod

28-grafana-nodes.png
    Grafana Node Exporter dashboard showing all three nodes


Security

29-non-root.png
    kubectl exec into a backend pod then running whoami showing a non-root user

30-readonly-fs.png
    attempting to create a file in the container root filesystem and getting permission denied
