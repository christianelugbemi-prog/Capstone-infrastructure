terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Remote state storage (for team collaboration)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "capstone/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
  
  # Optional: Profile if you have multiple AWS accounts
  # profile = "default"
}

# Get your public IP for security group
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# 1. VPC Module (Free)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "capstone-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a"]  # Dynamic AZ
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = []

  enable_nat_gateway = false  # Save cost
  enable_vpn_gateway = false
  single_nat_gateway = false

  tags = {
    Name    = "capstone-vpc"
    Project = "Capstone"
  }
}

# 2. Security Group for K3s EC2 (Free)
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-security-group"
  description = "Allow HTTP, HTTPS, SSH, and Kubernetes ports"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    description = "K3s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    description = "NodePort range for Kubernetes"
    from_port   = 30000
    to_port     = 32767
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

  tags = {
    Name    = "k3s-security-group"
    Project = "Capstone"
  }
}

# 3. EC2 Instance for K3s (t3.micro - Free Tier eligible)
resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = aws_key_pair.capstone_key.key_name
  associate_public_ip_address = true
  
  # Instance metadata options for security
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"  # "required" for production
  }
  
  # Root volume configuration
  root_block_device {
    volume_size = 20  # GB (Free Tier: 30GB EBS)
    volume_type = "gp3"
    encrypted   = true
    tags = {
      Name = "k3s-root-volume"
    }
  }

  # K3s installation script
  user_data = <<-EOF
              #!/bin/bash
              # Update system
              sudo apt-get update -y
              sudo apt-get upgrade -y
              
              # Install Docker (required for K3s)
              sudo apt-get install -y docker.io
              sudo systemctl enable docker
              sudo systemctl start docker
              
              # Install K3s (single node cluster)
              curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
              
              # Add current user to docker group
              sudo usermod -aG docker ubuntu
              
              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              rm kubectl
              
              # Install Helm
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              
              # Create kubeconfig for remote access
              mkdir -p /home/ubuntu/.kube
              sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
              sed -i 's/127.0.0.1/$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/g' /home/ubuntu/.kube/config
              
              # Create deployment directory
              mkdir -p /home/ubuntu/k8s-manifests
              
              # System info
              echo "=== System Information ===" > /home/ubuntu/setup-info.txt
              echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /home/ubuntu/setup-info.txt
              echo "K3s Version: $(k3s --version)" >> /home/ubuntu/setup-info.txt
              echo "Kubectl Version: $(kubectl version --short 2>/dev/null | grep Client)" >> /home/ubuntu/setup-info.txt
              echo "Docker Version: $(docker --version)" >> /home/ubuntu/setup-info.txt
              
              echo "Setup complete! The system will reboot in 30 seconds..."
              sleep 30
              sudo reboot
              EOF

  tags = {
    Name    = "k3s-server"
    Project = "Capstone"
    Type    = "Kubernetes-Master"
  }

  # Ensure instance is fully initialized
  provisioner "remote-exec" {
    inline = [
      "echo 'Instance is ready'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}

# 4. SSH Key Pair
resource "aws_key_pair" "capstone_key" {
  key_name   = "capstone-key-${formatdate("YYYYMMDD", timestamp())}"
  public_key = file("~/.ssh/id_rsa.pub")
  
  tags = {
    Project = "Capstone"
  }
}

# 5. Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 6. Elastic IP (Optional - if you want static IP)
# Note: Elastic IPs cost money if not attached to running instance
# resource "aws_eip" "k3s_eip" {
#   instance = aws_instance.k3s_server.id
#   domain   = "vpc"
#   tags = {
#     Name = "k3s-eip"
#   }
# }

# 7. IAM Role for EC2 (Optional - for enhanced permissions)
# resource "aws_iam_role" "ec2_role" {
#   name = "capstone-ec2-role"
#   
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }
# 
# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "capstone-ec2-profile"
#   role = aws_iam_role.ec2_role.name
# }