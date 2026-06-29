variable "aws_region" {
  description = "AWS region to deploy the cluster into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used on all resource names"
  type        = string
  default     = "capstone-phoenix"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for the k3s control plane node"
  type        = string
  default     = "t3.small"
}

variable "worker_instance_type" {
  description = "EC2 instance type for k3s worker nodes"
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file used for instance access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

