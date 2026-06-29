output "control_plane_ip" {
  description = "Public IP of the k3s control plane node"
  value       = aws_eip.control_plane.public_ip
}

output "worker_ips" {
  description = "Public IPs of the k3s worker nodes"
  value       = aws_eip.worker[*].public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane (used in k3s agent join command)"
  value       = aws_instance.control_plane.private_ip
}

output "ssh_connect_control_plane" {
  description = "SSH command to connect to the control plane"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.control_plane.public_ip}"
}

output "app_domain_hint" {
  description = "Use this sslip.io domain for your ingress (no DNS purchase needed)"
  value       = "taskapp.${aws_eip.control_plane.public_ip}.sslip.io"
}
