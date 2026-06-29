Cost Analysis


Why Free Tier Does Not Work Here

AWS Free Tier gives 750 hours per month of t2.micro which has 1 vCPU and 1 GB of RAM. That is not enough for this project. The control plane node alone needs to run k3s, Argo CD, cert-manager, the nginx ingress controller, and metrics-server. Together those need at least 2 GB of RAM. A t2.micro would run out of memory and the cluster would crash. The smallest instance that keeps the cluster stable is t3.small with 2 GB of RAM.


Actual Cost for This Project

All three nodes use t3.small (2 vCPU, 2 GB RAM). Prices are AWS us-east-1 on-demand.

The cluster runs for approximately 5 days from provisioning to the grading deadline which is about 120 hours.

EC2 instances: 3 nodes at $0.0208 per hour for 120 hours = $7.49
Elastic IPs: 3 IPs at $0.005 per hour for 120 hours = $1.80
EBS volume for control plane: 30 GB gp3 for 5 days = $0.74
EBS volumes for worker nodes: 20 GB each for 5 days = $0.49
EBS for Postgres PVC: 10 GB for 5 days = $0.25
S3 bucket for Terraform state: less than $0.01
DynamoDB lock table: less than $0.01

Total for one week: approximately $10.78

After receiving the grade, running terraform destroy removes all the EC2 instances, the VPC, and the Elastic IPs. Billing stops within a few minutes.


Monthly Cost if Running Long-Term

If the cluster ran for a full calendar month the cost would be:

3x t3.small EC2 instances: $45.74
3x Elastic IPs: $10.95
EBS storage across all nodes and PVCs: $5.60

Total per month: approximately $62.29


Ways to Reduce Cost

Reserved Instances

AWS lets you commit to using an instance for 1 year or 3 years in exchange for a lower hourly rate. A 1-year reservation on t3.small saves about 38 percent compared to on-demand. Three reserved t3.small instances would cost around $28.50 per month instead of $45.74, saving about $17 per month on compute alone.

Spot Instances for Workers

Worker nodes in this project are stateless. If a worker goes down, Kubernetes reschedules the pods to the remaining worker automatically. This makes workers a good candidate for Spot Instances. Spot pricing for t3.small in us-east-1 averages around $0.006 to $0.008 per hour compared to $0.0208 on-demand. Switching both workers to Spot would reduce their combined cost from about $30 per month to around $8. The PodDisruptionBudgets in this project make sure at least one replica of each service stays running if a Spot instance gets interrupted.

Scheduled Stop and Start

For a cluster that is not needed 24 hours a day, you can stop the EC2 instances during off-hours. Stopping them from 10pm to 8am removes 10 hours of compute billing per day. Over a month that saves roughly 40 percent of the EC2 cost. AWS Instance Scheduler can automate this on a cron schedule.

Running Two Nodes Instead of Three

For development or testing only, you could run one control plane and one worker. This removes one third of the EC2 cost. This is not valid for this capstone since the requirements say the cluster must have at least three nodes, but it is worth knowing for a real project.

Combined Saving Estimate

If you used Reserved pricing on the control plane, Spot on the workers, and scheduled stop/start, the monthly cost could drop from $62.29 to somewhere around $18 to $22 for a cluster with the same capability.
