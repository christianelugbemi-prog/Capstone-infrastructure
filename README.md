cat > README.md << 'EOF'
# Capstone Project - Infrastructure as Code

## Overview
This repository contains Terraform configurations for provisioning AWS infrastructure for the capstone project.

## Architecture
- AWS VPC with public subnet
- EC2 t3.micro instance (Free Tier eligible)
- Security groups for SSH, HTTP, and custom ports
- K3s Kubernetes cluster setup

## Prerequisites
- AWS Account with credentials
- Terraform v1.0+
- SSH key pair

## Deployment

### 1. Initialize Terraform
```bash
terraform init