locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${var.project_name}-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${var.project_name}-public-subnet" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security groups
# External: only SSH from my IP, HTTP and HTTPS from anywhere
resource "aws_security_group" "external" {
  name        = "${var.project_name}-external-sg"
  description = "Allow inbound SSH, HTTP, and HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH - key-based auth required, no password login possible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for cert-manager ACME challenge"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS application traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-external-sg" })
}

# Internal: cluster nodes talk to each other freely, k3s API only inside the VPC
resource "aws_security_group" "internal" {
  name        = "${var.project_name}-internal-sg"
  description = "Allow all traffic between cluster nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All traffic between cluster nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "k3s API server from within the VPC only"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-internal-sg" })
}

# SSH key pair
resource "aws_key_pair" "cluster" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)

  tags = local.common_tags
}

# Latest Ubuntu 22.04 LTS AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Control plane node
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_plane_instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.external.id, aws_security_group.internal.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-control-plane"
    Role = "control-plane"
  })
}

# Worker nodes
resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.cluster.key_name
  vpc_security_group_ids = [aws_security_group.external.id, aws_security_group.internal.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-worker-${count.index + 1}"
    Role = "worker"
  })
}

# Elastic IPs so the node IPs stay the same even after a restart
resource "aws_eip" "control_plane" {
  instance = aws_instance.control_plane.id
  domain   = "vpc"

  tags = merge(local.common_tags, { Name = "${var.project_name}-control-plane-eip" })
}

resource "aws_eip" "worker" {
  count    = var.worker_count
  instance = aws_instance.worker[count.index].id
  domain   = "vpc"

  tags = merge(local.common_tags, { Name = "${var.project_name}-worker-${count.index + 1}-eip" })
}
